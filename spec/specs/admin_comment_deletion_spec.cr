require "../spec_helper"
require "timecop"

describe "Administrator comment deletion" do
  around_each do |example|
    previous_emails = ENV["ADMIN_EMAILS"]?
    ENV["ADMIN_EMAILS"] = "cascade-admin@example.com"

    example.run
  ensure
    if previous_emails
      ENV["ADMIN_EMAILS"] = previous_emails
    else
      ENV.delete("ADMIN_EMAILS")
    end
  end

  it "rejects non-cascading deletion using current counts rather than the caller's stale record" do
    author = UserFactory.create
    doc = DocContent.sync("/docs/delete-operation-guard", "正文")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "root")
    child = CreateComment.create!(user_id: author.id, parent_id: root.id, content: "child")
    grandchild = CreateComment.create!(user_id: author.id, parent_id: child.id, content: "grandchild")
    notifications_count = NotificationQuery.new.select_count

    [root, child].each do |comment|
      comment.children_count.should eq(0)

      operation = DeleteComment.new(comment)

      operation.delete.should be_false
      operation.errors[:base].should_not be_empty
      comment.reload.soft_deleted?.should be_false
      comment.reload.updated_at.should eq(comment.updated_at)
    end

    CommentQuery.new.publicly_visible_comments.id.asc_order.map(&.id).should eq([root.id, child.id, grandchild.id])
    root.reload.descendants_count.should eq(2)
    thread.reload.root_comments_count.should eq(1)
    NotificationQuery.new.select_count.should eq(notifications_count)
  end

  it "filters public comments without joining their root comments" do
    sql = CommentQuery.new.publicly_visible_comments.to_sql.first.as(String)

    sql.should_not match(/JOIN\s+"?comments"?\b/i)
    sql.should contain("comment_threads")
    sql.should contain("topics")
    sql.should contain("docs")
    sql.should contain("soft_deleted_at")
  end

  {"root", "child"}.each do |target_kind|
    it "soft deletes a #{target_kind} and all its descendants without deleting sibling branches" do
      admin = UserFactory.create &.email("cascade-admin@example.com")
      author = UserFactory.create
      replier = UserFactory.create
      reader = UserFactory.create
      node = SaveNode.create!(name: "级联删除", slug: "cascade-delete", summary: "测试", color: "#16a34a", position: 0)
      topic = CreateTopic.create!(user_id: author.id, node_id: node.id, title: "级联删除", content: "主题正文")
      thread = CommentThreadQuery.new.topic_id(topic.id).first
      other_root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "other root")
      root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "cascade root")
      sibling = CreateComment.create!(user_id: replier.id, parent_id: root.id, content: "sibling")
      child = CreateComment.create!(user_id: replier.id, parent_id: root.id, content: "cascade child")
      grandchild = CreateComment.create!(user_id: reader.id, parent_id: child.id, content: "cascade grandchild")
      great_grandchild = CreateComment.create!(user_id: author.id, parent_id: grandchild.id, content: "cascade great grandchild")
      target = target_kind == "root" ? Comment::SaveOperation.update!(root, withdrawn: true) : child
      affected = target_kind == "root" ? [target, sibling, child, grandchild, great_grandchild] : [target, grandchild, great_grandchild]
      remaining = target_kind == "root" ? [other_root] : [other_root, root, sibling]
      last_remaining = remaining.last
      list_param = target_kind == "root" ? "comment_thread_id=#{thread.id}" : "root_id=#{root.id}"
      client = ApiClient.new
      response = client.get("/htmx/comments?#{list_param}&backdoor_user_id=#{admin.id}")
      delete_button = XML.parse_html(response.body).xpath_node("//button[@hx-delete='/htmx/comments/#{target.id}']").not_nil!

      response.status_code.should eq(200)
      delete_button["hx-confirm"].should eq("删除此评论及其全部回复？")

      Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
        # 普通作者不能通过客户端参数开启级联删除。
        client.delete("/htmx/comments/#{target.id}?backdoor_user_id=#{target.user_id}", delete_descendants: true).status_code.should eq(409)
        client.delete("/htmx/comments/#{target.id}?backdoor_user_id=#{reader.id}").status_code.should eq(403)

        response = client.delete("/htmx/comments/#{target.id}?backdoor_user_id=#{admin.id}")

        response.status_code.should eq(200)
        response.body.should_not contain(target.content)
        CommentQuery.new.id.asc_order.map(&.id).should eq(remaining.map(&.id).sort!)
        CommentQuery.new.only_soft_deleted.id.asc_order.map(&.id).should eq(affected.map(&.id).sort!)
        CommentQuery.new.only_soft_deleted.map(&.soft_deleted_at).uniq!.should eq([target.reload.soft_deleted_at])

        affected.each do |comment|
          deleted = comment.reload

          {deleted.content, deleted.content_html, deleted.floor, deleted.withdrawn?, deleted.edited_at}.should eq(
            {comment.content, comment.content_html, comment.floor, comment.withdrawn?, comment.edited_at}
          )

          if comment.id != target.id
            deleted.updated_at.should eq(comment.updated_at)
          end

          ApiClient.new.get("/comments/#{comment.id}").status_code.should eq(404)
        end

        topic = topic.reload

        topic.replies_count.should eq(remaining.size)
        topic.last_reply_user_id.should eq(last_remaining.user_id)
        topic.last_active_at.should eq(last_remaining.created_at)
        thread.reload.root_comments_count.should eq(remaining.count(&.parent_id.nil?))
        root.reload.descendants_count.should eq(target_kind == "root" ? 0 : 1)
        root.reload.children_count.should eq(target_kind == "root" ? 0 : 1)
        child.reload.children_count.should eq(0)
        grandchild.reload.children_count.should eq(0)
        deleted_notifications = NotificationQuery.new.kind(Notification::Kind::CommentDeleted).results

        deleted_notifications.size.should eq(1)
        notification = deleted_notifications.first

        {notification.user_id, notification.actor_id, notification.url}.should eq(
          {target.user_id, admin.id, "/comments/#{target.id}"}
        )
      end
    end
  end

  it "traverses previously deleted comments while preserving their deletion time and other branches" do
    admin = UserFactory.create &.email("cascade-admin@example.com")
    author = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/cascade-existing-deletions", content: "文档正文")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "root")
    target = CreateComment.create!(user_id: author.id, parent_id: root.id, content: "target")
    deleted_child = CreateComment.create!(user_id: author.id, parent_id: target.id, content: "previously deleted")
    grandchild = CreateComment.create!(user_id: author.id, parent_id: deleted_child.id, content: "live descendant")
    sibling = CreateComment.create!(user_id: author.id, parent_id: root.id, content: "sibling")
    earlier = Time.utc

    # 故意绕过删除校验，模拟旧数据，确认级联查询仍能穿过已删除的节点。
    Timecop.freeze(earlier) { Comment::SaveOperation.update!(deleted_child, soft_deleted_at: Time.utc) }

    deleted_child = deleted_child.reload

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      response = Timecop.freeze(earlier + 1.minute) do
        ApiClient.new.delete("/htmx/comments/#{target.id}?backdoor_user_id=#{admin.id}")
      end

      response.status_code.should eq(200)
      CommentQuery.new.id.asc_order.map(&.id).should eq([root.id, sibling.id])
      target.reload.soft_deleted_at.should eq(grandchild.reload.soft_deleted_at)
      target.reload.soft_deleted_at.should_not eq(deleted_child.soft_deleted_at)
      deleted_child.reload.soft_deleted_at.should eq(deleted_child.soft_deleted_at)
      deleted_child.reload.updated_at.should eq(deleted_child.updated_at)
      root.reload.children_count.should eq(1)
      root.reload.descendants_count.should eq(1)
      target.reload.children_count.should eq(0)
      deleted_child.reload.children_count.should eq(0)
      thread.reload.root_comments_count.should eq(1)
      response.body.should contain("sibling")
      response.body.should_not contain("live descendant")
    end
  end

  it "rolls back the whole branch, counters and notification when the surrounding transaction rolls back" do
    admin = UserFactory.create &.email("cascade-admin@example.com")
    author = UserFactory.create
    node = SaveNode.create!(name: "级联回滚", slug: "cascade-rollback", summary: "测试", color: "#16a34a", position: 0)
    topic = CreateTopic.create!(user_id: author.id, node_id: node.id, title: "级联回滚", content: "正文")
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "root")
    child = CreateComment.create!(user_id: author.id, parent_id: root.id, content: "child")
    notifications_count = NotificationQuery.new.select_count

    AppDatabase.transaction do
      DeleteComment.delete!(root, actor_id: admin.id, delete_descendants: true)

      CommentQuery.new.any?.should be_false
      topic.reload.replies_count.should eq(0)
      AppDatabase.rollback
    end

    CommentQuery.new.id.asc_order.map(&.id).should eq([root.id, child.id])
    root.reload.children_count.should eq(1)
    root.reload.descendants_count.should eq(1)
    thread.reload.root_comments_count.should eq(1)
    topic.reload.replies_count.should eq(2)
    NotificationQuery.new.select_count.should eq(notifications_count)
  end
end
