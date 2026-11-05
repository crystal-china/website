require "../spec_helper"

describe RestoreComment do
  it "restores comments in parent-first order without an HTTP action" do
    user = UserFactory.create
    doc = SaveDoc.create!(
      path_index: "/docs/restore-operation",
      content: "正文"
    )

    thread = CommentThreadQuery.new.doc_id(doc.id).first

    root = CreateComment.create!(
      user_id: user.id,
      comment_thread_id: thread.id,
      content: "根评论"
    )

    child = ReplyToComment.create!(
      user_id: user.id,
      parent_id: root.id,
      content: "**子评论**"
    )

    DeleteComment.delete!(root, delete_descendants: true)

    deleted_root = root.reload
    deleted_child = child.reload
    notifications_count = NotificationQuery.new.select_count

    RestoreComment.run(deleted_comment: deleted_child) do |operation, result|
      result.should be_nil
      operation.errors[:base].should eq(["不可恢复"])
    end

    expect_raises(Avram::FailedOperation) do
      RestoreComment.run!(deleted_comment: deleted_child)
    end

    child.reload.soft_deleted_at.should eq(deleted_child.soft_deleted_at)
    child.reload.updated_at.should eq(deleted_child.updated_at)
    thread.reload.root_comments_count.should eq(0)

    RestoreComment.run(deleted_comment: deleted_root) do |_operation, result|
      result.not_nil![:comment].soft_deleted?.should be_false
      result.not_nil![:deleted_at].should eq(deleted_root.soft_deleted_at)
      child.reload.soft_deleted?.should be_true
    end

    restored_child = RestoreComment.run!(deleted_comment: deleted_child)[:comment]

    restored_child.soft_deleted?.should be_false
    {restored_child.content, restored_child.content_html, restored_child.floor}.should eq(
      {child.content, child.content_html, child.floor}
    )
    root.reload.children_count.should eq(1)
    root.reload.descendants_count.should eq(1)
    thread.reload.root_comments_count.should eq(1)
    NotificationQuery.new.select_count.should eq(notifications_count)
  end

  it "rejects unavailable topics and documents when called directly" do
    user = UserFactory.create

    node = SaveNode.create!(
      name: "恢复检查",
      slug: "restore-check",
      summary: "测试",
      color: "#0284c7",
      position: 0
    )

    topic = CreateTopic.create!(
      user_id: user.id,
      node_id: node.id,
      title: "主题",
      content: "正文"
    )

    doc = SaveDoc.create!(
      path_index: "/docs/restore-unavailable",
      content: "正文"
    )

    topic_thread = CommentThreadQuery.new.topic_id(topic.id).first
    doc_thread = CommentThreadQuery.new.doc_id(doc.id).first

    topic_comment = CreateComment.create!(
      user_id: user.id,
      comment_thread_id: topic_thread.id,
      content: "主题评论"
    )

    doc_comment = CreateComment.create!(
      user_id: user.id,
      comment_thread_id: doc_thread.id,
      content: "文档评论"
    )

    DeleteComment.delete!(topic_comment)
    DeleteComment.delete!(doc_comment)
    DeleteTopic.delete!(topic)
    SaveDoc.update!(doc, content: nil)

    [topic_comment.reload, doc_comment.reload].each do |deleted_comment|
      RestoreComment.run(deleted_comment: deleted_comment) do |operation, result|
        result.should be_nil
        operation.errors[:base].should eq(["不可恢复"])
      end

      current_comment = deleted_comment.reload

      current_comment.soft_deleted_at.should eq(deleted_comment.soft_deleted_at)
      current_comment.updated_at.should eq(deleted_comment.updated_at)
    end

    topic.reload.replies_count.should eq(0)
    topic_thread.reload.root_comments_count.should eq(0)
    doc_thread.reload.root_comments_count.should eq(0)
  end
end
