require "../spec_helper"

private def notification_topic(author : User)
  node = SaveNode.create!(name: "通知测试", slug: "notifications", summary: "测试", color: "#16a34a", position: 0)
  SaveTopic.create!(user_id: author.id, node_id: node.id, title: "通知测试主题", content: "正文")
end

describe "Notifications" do
  it "deduplicates topic and direct-reply recipients and excludes the sender" do
    author = UserFactory.create
    responder = UserFactory.create
    topic = notification_topic(author)
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    root = SaveComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "自己的主题")
    NotificationQuery.new.select_count.should eq(0)

    child = SaveComment.create!(user_id: responder.id, parent_id: root.id, content: "回复作者")
    notifications = NotificationQuery.new.comment_id(child.id).results
    notifications.size.should eq(1)
    notifications.first.user_id.should eq(author.id)
    notifications.first.kind.should eq("comment_reply")

    grandchild = SaveComment.create!(user_id: author.id, parent_id: child.id, content: "再次回复")
    NotificationQuery.new.comment_id(grandchild.id).first.user_id.should eq(responder.id)

    mentioned_reply = SaveComment.create!(user_id: responder.id, parent_id: root.id, content: "@#{author.name} 明确提及")
    NotificationQuery.new.comment_id(mentioned_reply.id).select_count.should eq(1)
    NotificationQuery.new.comment_id(mentioned_reply.id).first.kind.should eq("mention")
  end

  it "notifies the topic author and a different parent author, and supports document replies" do
    author = UserFactory.create
    parent_author = UserFactory.create
    responder = UserFactory.create
    thread = CommentThreadQuery.new.topic_id(notification_topic(author).id).first
    root = SaveComment.create!(user_id: parent_author.id, comment_thread_id: thread.id, content: "根评论")
    child = SaveComment.create!(user_id: responder.id, parent_id: root.id, content: "子评论")
    NotificationQuery.new.comment_id(child.id).results.map(&.user_id).sort.should eq([author.id, parent_author.id].sort)

    doc = SaveDoc.create!(path_index: "/docs/notifications", content: "文档正文")
    doc_thread = CommentThreadQuery.new.doc_id(doc.id).first
    doc_root = SaveComment.create!(user_id: parent_author.id, comment_thread_id: doc_thread.id, content: "文档评论")
    NotificationQuery.new.comment_id(doc_root.id).any?.should be_false
    doc_child = SaveComment.create!(user_id: responder.id, parent_id: doc_root.id, content: "文档子评论")
    NotificationQuery.new.comment_id(doc_child.id).first.user_id.should eq(parent_author.id)
  end

  it "ignores code and email mentions, and notifies new mentions only once after editing" do
    author = UserFactory.create
    mentioned = UserFactory.create &.name("小明")
    added = UserFactory.create &.name("新朋友")
    code_user = UserFactory.create &.name("示例用户")
    thread = CommentThreadQuery.new.topic_id(notification_topic(author).id).first
    comment = SaveComment.create!(user_id: author.id, comment_thread_id: thread.id, content: <<-MARKDOWN)
      请@小明，看看这个例子。`@示例用户` 并不是提及。

      ```crystal
      @示例用户
      ```

      email@示例用户
      MARKDOWN

    NotificationQuery.new.comment_id(comment.id).results.map(&.user_id).should eq([mentioned.id])
    NotificationQuery.new.user_id(code_user.id).any?.should be_false
    NotificationQuery.new.user_id(mentioned.id).update(read_at: Time.utc)

    comment = UpdateComment.update!(comment, content: "@小明 @新朋友 @新朋友")
    UpdateComment.update!(comment, content: "@小明 @新朋友 再次编辑")
    NotificationQuery.new.comment_id(comment.id).select_count.should eq(2)
    NotificationQuery.new.user_id(mentioned.id).first.read_at.should_not be_nil
    NotificationQuery.new.user_id(added.id).first.kind.should eq("mention")
  end

  it "supports mentions in topics and limits mention recipients" do
    author = UserFactory.create
    users = 7.times.map { |index| UserFactory.create &.name("被提及#{index}") }.to_a
    topic = notification_topic(author)
    topic = UpdateTopic.update!(topic, content: users.map { |user| "@#{user.name}" }.join(" "))
    NotificationQuery.new.topic_id(topic.id).select_count.should eq(5)
    UpdateTopic.update!(topic, content: "#{topic.content} 再次编辑")
    NotificationQuery.new.topic_id(topic.id).select_count.should eq(5)

    new_topic = SaveTopic.create!(user_id: author.id, node_id: topic.node_id, title: "提及", content: "@#{users.last.name}")
    NotificationQuery.new.topic_id(new_topic.id).first.user_id.should eq(users.last.id)
  end

  it "prefers the exact username over stripping punctuation" do
    plain = UserFactory.create &.name("some.user")
    dotted = UserFactory.create &.name("some.user.")
    parentheses = UserFactory.create &.name("SomeUser(he/him)")
    UserMentions.user_ids("@some.user. @SomeUser(he/him)").should eq([dotted.id, parentheses.id])
    UserMentions.user_ids("@some.user").should eq([plain.id])
  end

  it "does not expose hidden content through notifications" do
    author = UserFactory.create
    responder = UserFactory.create
    topic = notification_topic(author)
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    root = SaveComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "私有根评论")
    child = SaveComment.create!(user_id: responder.id, parent_id: root.id, content: "隐藏正文不能泄露")
    DeleteComment.delete!(root)

    NotificationQuery.new.comment_id(child.id).for_display.first.target_visible?.should be_false
    response = ApiClient.new.get("/notifications?backdoor_user_id=#{author.id}")
    response.status_code.should eq(200)
    response.body.should contain("相关内容已删除或暂不可见")
    response.body.should_not contain("隐藏正文不能泄露")
    ApiClient.new.get("/comments/#{child.id}").status_code.should eq(404)

    CommentQuery.new.only_soft_deleted.id(root.id).first.restore
    DeleteTopic.delete!(topic)
    NotificationQuery.new.comment_id(child.id).for_display.first.target_visible?.should be_false
  end

  it "scopes read operations to the recipient and does not mark a list read automatically" do
    author = UserFactory.create
    responder = UserFactory.create
    thread = CommentThreadQuery.new.topic_id(notification_topic(author).id).first
    comment = SaveComment.create!(user_id: responder.id, comment_thread_id: thread.id, content: "回复")
    notification = NotificationQuery.new.comment_id(comment.id).first
    ApiClient.new.get("/notifications?backdoor_user_id=#{author.id}").status_code.should eq(200)
    NotificationQuery.find(notification.id).read_at.should be_nil

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      ApiClient.new.post("/notifications/#{notification.id}/read?backdoor_user_id=#{responder.id}").status_code.should eq(404)
      NotificationQuery.find(notification.id).read_at.should be_nil
      response = ApiClient.new.post("/notifications/#{notification.id}/read?backdoor_user_id=#{author.id}")
      response.status_code.should eq(303)
      response.headers["Location"].should contain("/comments/#{comment.id}")
      NotificationQuery.find(notification.id).read_at.should_not be_nil

      other = SaveNotification.create!(user_id: responder.id, actor_id: author.id, comment_id: comment.id, kind: "mention")
      ApiClient.new.post("/notifications/read_all?backdoor_user_id=#{author.id}").status_code.should eq(303)
      NotificationQuery.find(other.id).read_at.should be_nil
    end
  end

  it "locates root and child comments beyond the first page" do
    author = UserFactory.create
    responder = UserFactory.create
    thread = CommentThreadQuery.new.topic_id(notification_topic(author).id).first
    root = SaveComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "要定位的根评论")
    child = SaveComment.create!(user_id: responder.id, parent_id: root.id, content: "要定位的子评论")
    11.times do |index|
      SaveComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "较新根评论#{index}")
      SaveComment.create!(user_id: author.id, parent_id: root.id, content: "较新子评论#{index}")
    end

    root_response = ApiClient.new.get("/htmx/comments?comment_thread_id=#{thread.id}&comment_id=#{child.id}")
    root_response.status_code.should eq(200)
    root_response.body.should contain("要定位的根评论")
    root_response.body.should contain("正在定位评论")
    child_response = ApiClient.new.get("/htmx/comments?root_id=#{root.id}&comment_id=#{child.id}")
    child_response.status_code.should eq(200)
    child_response.body.should contain("要定位的子评论")
    child_response.body.should contain(%(data-focus-comment="true"))
    ApiClient.new.get("/comments/#{child.id}").headers["Location"].should contain("?comment_id=#{child.id}#comment-#{child.id}")
  end

  it "requires authentication for autocomplete and treats LIKE wildcards literally" do
    user = UserFactory.create
    UserFactory.create &.name("明月")
    UserFactory.create &.name("明天")
    UserFactory.create &.name("明_天")
    ApiClient.new.headers("HX-Request-Type": "partial").get("/htmx/mentions?q=#{URI.encode_path("明")}").status_code.should eq(401)
    response = ApiClient.new.get("/htmx/mentions?q=#{URI.encode_path("明_")}&backdoor_user_id=#{user.id}")
    response.status_code.should eq(200)
    Array(String).from_json(response.body).should eq(["明_天"])
  end
end
