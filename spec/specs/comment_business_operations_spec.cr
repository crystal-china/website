require "../spec_helper"

describe "Comment business operations" do
  around_each do |example|
    previous_emails = ENV["ADMIN_EMAILS"]?
    ENV["ADMIN_EMAILS"] = "comment-business-admin@example.com"

    example.run
  ensure
    if previous_emails
      ENV["ADMIN_EMAILS"] = previous_emails
    else
      ENV.delete("ADMIN_EMAILS")
    end
  end

  it "creates roots and nested replies with HTML, counters, notifications and reading positions" do
    author = UserFactory.create
    replier = UserFactory.create
    node = SaveNode.create!(name: "Comments", slug: "comment-business", summary: "Comments", color: "#0284c7", position: 0)
    topic = CreateTopic.create!(user_id: author.id, node_id: node.id, title: "Comments", content: "Topic")
    thread = topic.comment_thread.not_nil!
    root = CreateRootComment.run!(thread: thread, user_id: author.id, content: "**root**")
    child = CreateCommentReply.run!(parent: root, user_id: replier.id, content: "child")
    grandchild = CreateCommentReply.run!(parent: child, user_id: replier.id, content: "grandchild")

    root.content_html.should eq("<p><strong>root</strong></p>\n")
    root.vote_counts.👍.should eq(0)
    {child.parent_id, child.root_id, child.comment_thread_id}.should eq({root.id, root.id, thread.id})
    {grandchild.parent_id, grandchild.root_id, grandchild.comment_thread_id}.should eq({child.id, root.id, thread.id})
    root.reload.children_count.should eq(1)
    root.reload.descendants_count.should eq(2)
    thread.reload.root_comments_count.should eq(1)
    topic.reload.replies_count.should eq(3)
    TopicReadQuery.new.topic_id(topic.id).user_id(replier.id).first.last_read_reply_id.should eq(grandchild.id)

    notification = NotificationQuery.new.for_target(child).first

    {notification.user_id, notification.actor_id, notification.kind}.should eq(
      {author.id, replier.id, Notification::Kind::CommentReply}
    )
  end

  it "rejects creation, replies, editing and deletion before locking when a document becomes unavailable" do
    author = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/comment-business-unavailable", content: "Document")
    thread = doc.comment_thread!.not_nil!
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "root")
    child = ReplyToComment.create!(user_id: author.id, parent_id: root.id, content: "child")
    notifications_count = NotificationQuery.new.select_count

    SaveDoc.update!(doc, content: nil)

    test_mode = Pulsar.test_mode_enabled?
    Pulsar.test_mode_enabled = true
    Avram::Events::QueryEvent.logged_events.clear

    CreateRootComment.run(thread: thread, user_id: author.id, content: "too late") do |operation, comment|
      comment.should be_nil
      operation.rejection_reason.should eq(CreateRootComment::RejectionReason::TargetUnavailable)
    end

    CreateCommentReply.run(parent: root, user_id: author.id, content: "too late") do |operation, comment|
      comment.should be_nil
      operation.rejection_reason.should eq(CreateCommentReply::RejectionReason::TargetUnavailable)
    end

    EditComment.run(comment: child, actor: author, content: "too late") do |operation, comment|
      comment.should be_nil
      operation.rejection_reason.should eq(EditComment::RejectionReason::TargetUnavailable)
    end

    RemoveComment.run(comment: child, actor: author) do |operation, comment|
      comment.should be_nil
      operation.rejection_reason.should eq(RemoveComment::RejectionReason::TargetUnavailable)
    end

    queries = Avram::Events::QueryEvent.logged_events.map(&.query)

    queries.should_not be_empty
    queries.none?(&.includes?("FOR UPDATE")).should be_true
    CommentQuery.new.select_count.should eq(2)
    child.reload.content.should eq("child")
    thread.reload.root_comments_count.should eq(1)
    root.reload.descendants_count.should eq(1)
    NotificationQuery.new.select_count.should eq(notifications_count)
  ensure
    Pulsar.test_mode_enabled = test_mode if test_mode.is_a?(Bool)
    Avram::Events::QueryEvent.logged_events.clear
  end

  it "rejects roots and replies under a soft-deleted topic" do
    author = UserFactory.create
    node = SaveNode.create!(name: "Deleted", slug: "comment-business-deleted", summary: "Deleted", color: "#0284c7", position: 0)
    topic = CreateTopic.create!(user_id: author.id, node_id: node.id, title: "Deleted", content: "Topic")
    thread = topic.comment_thread.not_nil!
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "root")

    DeleteTopic.delete!(topic)

    CreateRootComment.run(thread: thread, user_id: author.id, content: "too late") do |operation, comment|
      comment.should be_nil
      operation.rejection_reason.should eq(CreateRootComment::RejectionReason::TargetUnavailable)
    end

    CreateCommentReply.run(parent: root, user_id: author.id, content: "too late") do |operation, comment|
      comment.should be_nil
      operation.rejection_reason.should eq(CreateCommentReply::RejectionReason::TargetUnavailable)
    end

    CommentQuery.new.select_count.should eq(1)
    root.reload.children_count.should eq(0)
  end

  it "allows the author and an administrator to edit while preserving HTML and management notifications" do
    author = UserFactory.create
    admin = UserFactory.create &.email("comment-business-admin@example.com")
    doc = SaveDoc.create!(path_index: "/docs/comment-business-edit", content: "Document")
    root = CreateComment.create!(user_id: author.id, comment_thread_id: doc.comment_thread!.not_nil!.id, content: "root")
    child = ReplyToComment.create!(user_id: author.id, parent_id: root.id, content: "child")

    edited_root = EditComment.run!(comment: root, actor: author, content: "**edited root**")
    edited_child = EditComment.run!(comment: child, actor: admin, content: "**edited child**")

    edited_root.content_html.should eq("<p><strong>edited root</strong></p>\n")
    edited_child.content_html.should eq("<p><strong>edited child</strong></p>\n")
    edited_root.edited_at.should_not be_nil
    edited_child.edited_at.should_not be_nil
    edited_child.user_id.should eq(author.id)
    root.reload.descendants_count.should eq(1)

    notification = NotificationQuery.new.for_target(child).kind(Notification::Kind::CommentEdited).first

    {notification.user_id, notification.actor_id}.should eq({author.id, admin.id})
    NotificationQuery.new.for_target(root).any?.should be_false
  end

  it "rejects another user's edits and prevents both authors and administrators from editing withdrawn content" do
    author = UserFactory.create
    other = UserFactory.create
    admin = UserFactory.create &.email("comment-business-admin@example.com")
    doc = SaveDoc.create!(path_index: "/docs/comment-business-forbidden", content: "Document")
    comment = CreateComment.create!(user_id: author.id, comment_thread_id: doc.comment_thread!.not_nil!.id, content: "original")
    notifications_count = NotificationQuery.new.select_count

    EditComment.run(comment: comment, actor: other, content: "forbidden") do |operation, result|
      result.should be_nil
      operation.rejection_reason.should eq(EditComment::RejectionReason::Forbidden)
    end

    withdrawn_comment = SetCommentWithdrawal.run!(comment_id: comment.id, actor: author, withdrawn: true)

    {author, admin}.each do |actor|
      EditComment.run(comment: withdrawn_comment, actor: actor, content: "withdrawn") do |operation, result|
        result.should be_nil
        operation.rejection_reason.should eq(EditComment::RejectionReason::Withdrawn)
      end
    end

    comment.reload.content.should eq("original")
    comment.reload.edited_at.should be_nil
    comment.reload.withdrawn?.should be_true
    NotificationQuery.new.select_count.should eq(notifications_count)
  end

  it "keeps required-content validation when called without an HTTP action" do
    author = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/comment-business-validation", content: "Document")
    thread = doc.comment_thread!.not_nil!
    comment = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "original")

    expect_raises(Avram::InvalidOperationError) do
      CreateRootComment.run!(thread: thread, user_id: author.id, content: " ")
    end

    expect_raises(Avram::InvalidOperationError) do
      CreateCommentReply.run!(parent: comment, user_id: author.id, content: " ")
    end

    expect_raises(Avram::InvalidOperationError) do
      EditComment.run!(comment: comment, content: " ", actor: author)
    end

    CommentQuery.new.select_count.should eq(1)
    comment.reload.content.should eq("original")
    comment.reload.edited_at.should be_nil
  end

  it "rejects permissions, withdrawal and known replies before taking locks" do
    author = UserFactory.create
    other = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/comment-business-fast-rejection", content: "Document")
    root = CreateComment.create!(user_id: author.id, comment_thread_id: doc.comment_thread!.not_nil!.id, content: "original")
    child = ReplyToComment.create!(user_id: author.id, parent_id: root.id, content: "child")
    withdrawn_root = SetCommentWithdrawal.run!(comment_id: root.id, actor: author, withdrawn: true)
    test_mode = Pulsar.test_mode_enabled?
    Pulsar.test_mode_enabled = true
    Avram::Events::QueryEvent.logged_events.clear

    EditComment.run(comment: withdrawn_root, actor: other, content: "forbidden") do |operation, comment|
      comment.should be_nil
      operation.rejection_reason.should eq(EditComment::RejectionReason::Forbidden)
    end

    EditComment.run(comment: withdrawn_root, actor: author, content: "withdrawn") do |operation, comment|
      comment.should be_nil
      operation.rejection_reason.should eq(EditComment::RejectionReason::Withdrawn)
    end

    RemoveComment.run(comment: withdrawn_root, actor: other) do |operation, comment|
      comment.should be_nil
      operation.rejection_reason.should eq(RemoveComment::RejectionReason::Forbidden)
    end

    RemoveComment.run(comment: withdrawn_root, actor: author) do |operation, comment|
      comment.should be_nil
      operation.rejection_reason.should eq(RemoveComment::RejectionReason::HasReplies)
    end

    queries = Avram::Events::QueryEvent.logged_events.map(&.query)

    queries.should_not be_empty
    queries.none?(&.includes?("FOR UPDATE")).should be_true
    root.reload.content.should eq("original")
    root.reload.soft_deleted?.should be_false
    child.reload.soft_deleted?.should be_false
  ensure
    Pulsar.test_mode_enabled = test_mode if test_mode.is_a?(Bool)
    Avram::Events::QueryEvent.logged_events.clear
  end

  it "checks ownership and current reply counts before allowing an author to delete" do
    author = UserFactory.create
    other = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/comment-business-delete", content: "Document")
    thread = doc.comment_thread!.not_nil!
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "root")
    child = ReplyToComment.create!(user_id: author.id, parent_id: root.id, content: "child")
    grandchild = ReplyToComment.create!(user_id: author.id, parent_id: child.id, content: "grandchild")

    RemoveComment.run(comment: grandchild, actor: other) do |operation, comment|
      comment.should be_nil
      operation.rejection_reason.should eq(RemoveComment::RejectionReason::Forbidden)
    end

    {root, child}.each do |target|
      RemoveComment.run(comment: target, actor: author) do |operation, comment|
        comment.should be_nil
        operation.rejection_reason.should eq(RemoveComment::RejectionReason::HasReplies)
      end
    end

    CommentQuery.new.select_count.should eq(3)
    root.reload.descendants_count.should eq(2)

    {grandchild, child, root}.each do |target|
      removed = RemoveComment.run!(comment: target, actor: author)

      removed.id.should eq(target.id)
      removed.soft_deleted?.should be_true
    end

    CommentQuery.new.any?.should be_false
    thread.reload.root_comments_count.should eq(0)
    NotificationQuery.new.any?.should be_false
  end

  it "allows an administrator to cascade-delete a branch without deleting its siblings" do
    author = UserFactory.create
    admin = UserFactory.create &.email("comment-business-admin@example.com")
    doc = SaveDoc.create!(path_index: "/docs/comment-business-cascade", content: "Document")
    thread = doc.comment_thread!.not_nil!
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "root")
    child = ReplyToComment.create!(user_id: author.id, parent_id: root.id, content: "child")
    grandchild = ReplyToComment.create!(user_id: author.id, parent_id: child.id, content: "grandchild")
    sibling = ReplyToComment.create!(user_id: author.id, parent_id: root.id, content: "sibling")

    deleted = RemoveComment.run!(comment: child, actor: admin)

    deleted.soft_deleted?.should be_true
    grandchild.reload.soft_deleted_at.should eq(deleted.soft_deleted_at)
    CommentQuery.new.id.asc_order.map(&.id).should eq([root.id, sibling.id])
    root.reload.children_count.should eq(1)
    root.reload.descendants_count.should eq(1)
    thread.reload.root_comments_count.should eq(1)

    notification = NotificationQuery.new.for_target(child).kind(Notification::Kind::CommentDeleted).first

    {notification.user_id, notification.actor_id}.should eq({author.id, admin.id})
  end

  it "rolls back replies, counters, notifications and reading positions together" do
    author = UserFactory.create
    replier = UserFactory.create
    node = SaveNode.create!(name: "Rollback", slug: "comment-business-rollback", summary: "Rollback", color: "#0284c7", position: 0)
    topic = CreateTopic.create!(user_id: author.id, node_id: node.id, title: "Rollback", content: "Topic")
    thread = topic.comment_thread.not_nil!
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "root")

    AppDatabase.transaction do
      comment = CreateCommentReply.run!(parent: root, user_id: replier.id, content: "reply")

      CommentQuery.new.id(comment.id).any?.should be_true
      root.reload.descendants_count.should eq(1)
      topic.reload.replies_count.should eq(2)
      NotificationQuery.new.for_target(comment).any?.should be_true
      TopicReadQuery.new.topic_id(topic.id).user_id(replier.id).any?.should be_true

      AppDatabase.rollback
    end

    CommentQuery.new.id.asc_order.map(&.id).should eq([root.id])
    NotificationQuery.new.any?.should be_false
    TopicReadQuery.new.topic_id(topic.id).user_id(replier.id).any?.should be_false
    root.reload.descendants_count.should eq(0)
    thread.reload.root_comments_count.should eq(1)
    topic.reload.replies_count.should eq(1)
  end
end
