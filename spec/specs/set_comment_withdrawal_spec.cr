require "../spec_helper"

describe SetCommentWithdrawal do
  it "withdraws and restores roots and replies without changing their content or counters" do
    author = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/change-withdrawal", content: "正文")
    thread = doc.comment_thread!.not_nil!
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "根评论")
    child = ReplyToComment.create!(user_id: author.id, parent_id: root.id, content: "**子评论**")
    root = root.reload
    notifications_count = NotificationQuery.new.select_count

    {root, child}.each do |comment|
      {true, true, false, false}.each do |withdrawn|
        result = SetCommentWithdrawal.run!(
          comment_id: comment.id,
          actor: author,
          withdrawn: withdrawn
        )

        result.withdrawn?.should eq(withdrawn)
        {result.content, result.content_html, result.floor, result.edited_at}.should eq(
          {comment.content, comment.content_html, comment.floor, comment.edited_at}
        )
        result.soft_deleted_at.should be_nil
        result.children_count.should eq(comment.children_count)
        result.descendants_count.should eq(comment.descendants_count)
      end
    end

    thread.reload.root_comments_count.should eq(1)
    NotificationQuery.new.select_count.should eq(notifications_count)
  end

  it "rejects another user for either operation without an HTTP action" do
    author = UserFactory.create
    other = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/change-withdrawal-forbidden", content: "正文")
    comment = CreateComment.create!(user_id: author.id, comment_thread_id: doc.comment_thread!.not_nil!.id, content: "正文")

    {true, false}.each do |withdrawn|
      SetCommentWithdrawal.run(
        comment_id: comment.id,
        actor: other,
        withdrawn: withdrawn
      ) do |operation, result|
        result.should be_nil
        operation.rejection_reason.should eq(SetCommentWithdrawal::RejectionReason::Forbidden)
      end
    end

    comment.reload.withdrawn?.should be_false
  end

  it "allows an administrator to withdraw and restore another user's comment" do
    admin_emails = ENV["ADMIN_EMAILS"]?
    ENV["ADMIN_EMAILS"] = "withdrawal-operation-admin@example.com"

    author = UserFactory.create
    admin = UserFactory.create &.email("withdrawal-operation-admin@example.com")
    doc = SaveDoc.create!(path_index: "/docs/change-withdrawal-admin", content: "正文")
    comment = CreateComment.create!(user_id: author.id, comment_thread_id: doc.comment_thread!.not_nil!.id, content: "正文")

    {true, false}.each do |withdrawn|
      result = SetCommentWithdrawal.run!(
        comment_id: comment.id,
        actor: admin,
        withdrawn: withdrawn
      )

      result.withdrawn?.should eq(withdrawn)
    end
  ensure
    if admin_emails
      ENV["ADMIN_EMAILS"] = admin_emails
    else
      ENV.delete("ADMIN_EMAILS")
    end
  end

  it "rejects either operation when the source document is no longer available" do
    author = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/change-withdrawal-unavailable", content: "正文")
    comment = CreateComment.create!(user_id: author.id, comment_thread_id: doc.comment_thread!.not_nil!.id, content: "正文")

    SetCommentWithdrawal.run!(comment_id: comment.id, actor: author, withdrawn: true)
    SaveDoc.update!(doc, content: nil)

    {true, false}.each do |withdrawn|
      SetCommentWithdrawal.run(
        comment_id: comment.id,
        actor: author,
        withdrawn: withdrawn
      ) do |operation, result|
        result.should be_nil
        operation.rejection_reason.should eq(SetCommentWithdrawal::RejectionReason::TargetUnavailable)
      end
    end

    comment.reload.withdrawn?.should be_true
  end
end
