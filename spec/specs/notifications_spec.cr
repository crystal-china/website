require "../spec_helper"

private def notification_topic(author : User)
  node = SaveNode.create!(name: "通知测试", slug: "notifications", summary: "测试", color: "#16a34a", position: 0)
  CreateTopic.create!(user_id: author.id, node_id: node.id, title: "通知测试主题", content: "正文")
end

describe "Management notifications" do
  around_each do |example|
    admin_emails = ENV["ADMIN_EMAILS"]?
    ENV["ADMIN_EMAILS"] = "notification-admin@example.com"

    example.run
  ensure
    if admin_emails
      ENV["ADMIN_EMAILS"] = admin_emails
    else
      ENV.delete("ADMIN_EMAILS")
    end
  end

  it "allows a later mention after a reply, but deduplicates repeated mentions" do
    author = UserFactory.create
    responder = UserFactory.create
    thread = CommentThreadQuery.new.topic_id(notification_topic(author).id).first
    comment = CreateComment.create!(user_id: responder.id, comment_thread_id: thread.id, content: "普通回复")
    reply_notification = NotificationQuery.new.user_id(author.id).first
    SaveNotification.update!(reply_notification, read_at: Time.utc)

    comment = UpdateComment.update!(comment, content: "@#{author.name} 补充说明", actor_id: responder.id)
    UpdateComment.update!(comment, content: "#{comment.content} 再次编辑", actor_id: responder.id)

    notifications = NotificationQuery.new.user_id(author.id).id.asc_order.results
    notifications.map(&.kind).should eq([Notification::Kind::TopicReply, Notification::Kind::Mention])
    notifications.last.actor_id.should eq(responder.id)
    NotificationQuery.find(reply_notification.id).read_at.should_not be_nil
  end

  it "notifies topic owners of actual edits and moves, including repeated operations" do
    author = UserFactory.create
    admin = UserFactory.create &.email("notification-admin@example.com")
    topic = notification_topic(author)
    node = SaveNode.create!(name: "新节点", slug: "new-node", summary: "测试", color: "#16a34a", position: 0)
    original_node_id = topic.node_id

    topic = UpdateTopic.update!(topic, title: "管理员修改的标题", content: "管理员修改的正文", actor_id: admin.id)
    topic = UpdateTopic.update!(topic, content: "管理员再次修改的正文", actor_id: admin.id)
    topic = UpdateTopic.update!(topic, node_id: node.id, actor_id: admin.id)
    topic = UpdateTopic.update!(topic, node_id: original_node_id, actor_id: admin.id)
    UpdateTopic.update!(topic, title: topic.title, content: topic.content, node_id: topic.node_id, actor_id: admin.id)

    notifications = NotificationQuery.new.user_id(author.id).id.asc_order.results
    notifications.map(&.kind).should eq([
      Notification::Kind::TopicEdited,
      Notification::Kind::TopicEdited,
      Notification::Kind::TopicMoved,
      Notification::Kind::TopicMoved,
    ])
    notifications.map(&.actor_id).uniq.should eq([admin.id])
    notifications.first.source_title.should eq("管理员修改的标题")
    notifications.first.excerpt.should eq("管理员修改的正文")
    notifications[2].excerpt.should eq("新节点：新节点")
    NotificationQuery.new.user_id(admin.id).any?.should be_false

    UpdateTopic.update!(topic, content: "作者自己编辑", node_id: node.id, actor_id: author.id)
    NotificationQuery.new.select_count.should eq(4)
  end

  it "uses the editor as actor for document comment edits and mentions" do
    author = UserFactory.create
    admin = UserFactory.create &.email("notification-admin@example.com")
    mentioned = UserFactory.create
    doc = SaveDoc.create!(path_index: "/docs/management-notifications", content: "文档正文")
    thread = CommentThreadQuery.new.doc_id(doc.id).first
    comment = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "原评论")

    comment = UpdateComment.update!(comment, content: "@#{mentioned.name} 管理员补充", actor_id: admin.id)
    comment = UpdateComment.update!(comment, content: "再次补充", actor_id: admin.id)
    UpdateComment.update!(comment, content: comment.content, actor_id: admin.id)

    notifications = NotificationQuery.new.user_id(author.id).results
    notifications.map(&.kind).should eq([Notification::Kind::CommentEdited, Notification::Kind::CommentEdited])
    notifications.map(&.actor_id).uniq.should eq([admin.id])
    mention = NotificationQuery.new.user_id(mentioned.id).first
    mention.kind.should eq(Notification::Kind::Mention)
    mention.actor_id.should eq(admin.id)
    mention.url.should eq("/comments/#{comment.id}")
  end

  it "notifies deletions again after restoration without notifying self-deletions" do
    author = UserFactory.create
    admin = UserFactory.create &.email("notification-admin@example.com")
    topic = notification_topic(author)
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    comment = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "被删除的评论")

    DeleteComment.delete!(comment, actor_id: admin.id)
    comment = CommentQuery.new.only_soft_deleted.id(comment.id).first.restore
    NotificationQuery.new.select_count.should eq(1)
    DeleteComment.delete!(comment, actor_id: admin.id)
    DeleteTopic.delete!(topic, actor_id: admin.id)
    topic = TopicQuery.new.only_soft_deleted.id(topic.id).first.restore
    NotificationQuery.new.select_count.should eq(3)
    DeleteTopic.delete!(topic, actor_id: admin.id)

    notifications = NotificationQuery.new.user_id(author.id).id.asc_order.results
    notifications.map(&.kind).should eq([
      Notification::Kind::CommentDeleted,
      Notification::Kind::CommentDeleted,
      Notification::Kind::TopicDeleted,
      Notification::Kind::TopicDeleted,
    ])
    notifications.map(&.actor_id).uniq.should eq([admin.id])
    notifications.first.excerpt.should eq("被删除的评论")

    topic = TopicQuery.new.only_soft_deleted.id(topic.id).first.restore
    comment = CommentQuery.new.only_soft_deleted.id(comment.id).first.restore
    DeleteComment.delete!(comment, actor_id: author.id)
    DeleteTopic.delete!(topic, actor_id: author.id)
    NotificationQuery.new.select_count.should eq(4)
  end

  it "takes the operator from the session and rejects unauthorized changes" do
    author = UserFactory.create
    admin = UserFactory.create &.email("notification-admin@example.com")
    outsider = UserFactory.create
    topic = notification_topic(author)
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    comment = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "原评论")

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      response = ApiClient.new.put("/forum/#{topic.id}?backdoor_user_id=#{outsider.id}", topic: {title: "非法修改"}, content: "非法修改")
      response.status_code.should eq(403)
      response = ApiClient.new.post("/htmx/comments?backdoor_user_id=#{outsider.id}", id: comment.id, op: "edit", content: "非法修改")
      response.status_code.should eq(403)
      NotificationQuery.new.select_count.should eq(0)

      response = ApiClient.new.put("/forum/#{topic.id}?backdoor_user_id=#{admin.id}", topic: {title: "新标题", actor_id: outsider.id}, content: "新正文")
      response.status_code.should eq(303)
      response = ApiClient.new.post("/htmx/comments?backdoor_user_id=#{admin.id}", id: comment.id, op: "edit", content: "新评论", comment: {actor_id: outsider.id})
      response.status_code.should eq(200)
      ApiClient.new.delete("/htmx/comments/#{comment.id}?backdoor_user_id=#{admin.id}").status_code.should eq(200)
      ApiClient.new.delete("/forum/#{topic.id}?backdoor_user_id=#{admin.id}").status_code.should eq(303)
    end

    notifications = NotificationQuery.new.user_id(author.id).id.asc_order.results
    notifications.map(&.kind).should eq([
      Notification::Kind::TopicEdited,
      Notification::Kind::CommentEdited,
      Notification::Kind::CommentDeleted,
      Notification::Kind::TopicDeleted,
    ])
    notifications.map(&.actor_id).uniq.should eq([admin.id])
  end

  it "deduplicates repeated deliveries and rolls back notifications with content changes" do
    author = UserFactory.create
    responder = UserFactory.create
    topic = notification_topic(author)
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    comment = CreateComment.create!(user_id: responder.id, comment_thread_id: thread.id, content: "普通回复")
    NotificationQuery.new.delete

    2.times { NotificationDelivery.comment_created(comment) }
    NotificationQuery.new.select_count.should eq(1)

    AppDatabase.transaction do
      UpdateTopic.update!(topic, content: "需要回滚的编辑", actor_id: responder.id)
      AppDatabase.rollback
    end

    TopicQuery.find(topic.id).content.should eq(topic.content)
    NotificationQuery.new.select_count.should eq(1)
  end
end

describe "Mention notification preferences" do
  it "defaults to enabled and hides opted-out users from autocomplete until re-enabled" do
    user = UserFactory.create
    other = UserFactory.create
    user.mention_notifications_enabled.should be_true
    response = ApiClient.new.get("/me/edit?backdoor_user_id=#{user.id}")
    response.status_code.should eq(200)
    response.body.should contain("接收 @提及通知")
    response.body.should contain(%(name="user:mention_notifications_enabled"))

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      response = ApiClient.new.put("/me/update?backdoor_user_id=#{user.id}", user: {mention_notifications_enabled: "false"})
      response.status_code.should eq(303)
      UserQuery.find(user.id).mention_notifications_enabled.should be_false
      UserQuery.find(other.id).mention_notifications_enabled.should be_true
      UserAuditQuery.new.user_id(user.id).any?.should be_false

      response = ApiClient.new.get("/htmx/mentions?q=#{URI.encode_path(user.name)}&backdoor_user_id=#{user.id}")
      Array(String).from_json(response.body).should_not contain(user.name)

      response = ApiClient.new.get("/htmx/mentions?q=#{URI.encode_path(user.name)}&backdoor_user_id=#{other.id}")
      Array(String).from_json(response.body).should_not contain(user.name)

      response = ApiClient.new.put("/me/update?backdoor_user_id=#{user.id}", user: {mention_notifications_enabled: "true"})
      response.status_code.should eq(303)
      UserQuery.find(user.id).mention_notifications_enabled.should be_true

      response = ApiClient.new.get("/htmx/mentions?q=#{URI.encode_path(user.name)}&backdoor_user_id=#{user.id}")
      Array(String).from_json(response.body).should contain(user.name)
    end
  end

  it "blocks future mentions from authors, editors and oneself while preserving history" do
    author = UserFactory.create
    mentioned = UserFactory.create
    editor = UserFactory.create
    topic = notification_topic(author)
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "@#{mentioned.name} 原有提及")
    historical = NotificationQuery.new.user_id(mentioned.id).first

    mentioned = UpdateUser.update!(mentioned, mention_notifications_enabled: false)
    topic = UpdateTopic.update!(topic, content: "@#{mentioned.name} 主题提及", actor_id: author.id)
    comment = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "@#{mentioned.name} 新评论提及")
    UpdateComment.update!(comment, content: "@#{mentioned.name} 他人编辑提及", actor_id: editor.id)
    CreateComment.create!(user_id: mentioned.id, comment_thread_id: thread.id, content: "@#{mentioned.name} 提及自己")
    NotificationQuery.new.user_id(mentioned.id).select_count.should eq(1)
    NotificationQuery.find(historical.id).excerpt.should eq("@#{mentioned.name} 原有提及")

    UpdateUser.update!(mentioned, mention_notifications_enabled: true)
    UpdateTopic.update!(topic, content: "@#{mentioned.name} 重新接收提及", actor_id: author.id)
    NotificationQuery.new.user_id(mentioned.id).url("/forum/#{topic.id}").first.kind.should eq(Notification::Kind::Mention)
  end

  it "does not suppress ordinary replies or management events when mention notifications are disabled" do
    author = UserFactory.create
    responder = UserFactory.create
    topic = notification_topic(author)
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "根评论")
    UpdateUser.update!(author, mention_notifications_enabled: false)

    top = CreateComment.create!(user_id: responder.id, comment_thread_id: thread.id, content: "@#{author.name} 普通主题回复")
    child = CreateComment.create!(user_id: responder.id, parent_id: root.id, content: "@#{author.name} 直接回复")
    NotificationQuery.new.user_id(author.id).url("/comments/#{top.id}").first.kind.should eq(Notification::Kind::TopicReply)
    NotificationQuery.new.user_id(author.id).url("/comments/#{child.id}").first.kind.should eq(Notification::Kind::CommentReply)

    root = UpdateComment.update!(root, content: "@#{author.name} 编辑根评论", actor_id: responder.id)
    DeleteComment.delete!(root, actor_id: responder.id)
    notifications = NotificationQuery.new.user_id(author.id).url("/comments/#{root.id}").id.asc_order.results
    notifications.map(&.kind).should eq([Notification::Kind::CommentEdited, Notification::Kind::CommentDeleted])
    NotificationQuery.new.user_id(author.id).kind(Notification::Kind::Mention).any?.should be_false
  end
end

describe "Notifications" do
  it "deduplicates topic and direct-reply recipients and excludes implicit self-notifications" do
    author = UserFactory.create
    responder = UserFactory.create
    topic = notification_topic(author)
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "自己的主题")
    NotificationQuery.new.select_count.should eq(0)

    child = CreateComment.create!(user_id: responder.id, parent_id: root.id, content: "回复作者")
    notifications = NotificationQuery.new.url("/comments/#{child.id}").results
    notifications.size.should eq(1)
    notifications.first.user_id.should eq(author.id)
    notifications.first.kind.should eq(Notification::Kind::CommentReply)

    grandchild = CreateComment.create!(user_id: author.id, parent_id: child.id, content: "再次回复")
    NotificationQuery.new.url("/comments/#{grandchild.id}").first.user_id.should eq(responder.id)

    mentioned_reply = CreateComment.create!(user_id: responder.id, parent_id: root.id, content: "@#{author.name} 明确提及")
    NotificationQuery.new.url("/comments/#{mentioned_reply.id}").select_count.should eq(1)
    NotificationQuery.new.url("/comments/#{mentioned_reply.id}").first.kind.should eq(Notification::Kind::Mention)
  end

  it "allows explicit self-mentions but does not notify ordinary self-replies" do
    author = UserFactory.create &.name("小明")
    topic = notification_topic(author)
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "自己的主题")
    CreateComment.create!(user_id: author.id, parent_id: root.id, content: "回复自己")
    NotificationQuery.new.select_count.should eq(0)

    child = CreateComment.create!(user_id: author.id, parent_id: root.id, content: "@小明 明确提及自己")
    notification = NotificationQuery.new.url("/comments/#{child.id}").first
    notification.user_id.should eq(author.id)
    notification.kind.should eq(Notification::Kind::Mention)

    UpdateComment.update!(root, content: "@小明 编辑时提及自己")
    NotificationQuery.new.url("/comments/#{root.id}").first.user_id.should eq(author.id)
    UpdateTopic.update!(topic, content: "@小明 主题里提及自己")
    NotificationQuery.new.url("/forum/#{topic.id}").first.user_id.should eq(author.id)
    new_topic = CreateTopic.create!(user_id: author.id, node_id: topic.node_id, title: "自我提及", content: "@小明")
    NotificationQuery.new.url("/forum/#{new_topic.id}").first.user_id.should eq(author.id)
  end

  it "notifies the topic author and a different parent author, and supports document replies" do
    author = UserFactory.create
    parent_author = UserFactory.create
    responder = UserFactory.create
    thread = CommentThreadQuery.new.topic_id(notification_topic(author).id).first
    root = CreateComment.create!(user_id: parent_author.id, comment_thread_id: thread.id, content: "根评论")
    child = CreateComment.create!(user_id: responder.id, parent_id: root.id, content: "子评论")
    NotificationQuery.new.url("/comments/#{child.id}").results.map(&.user_id).sort.should eq([author.id, parent_author.id].sort)

    doc = SaveDoc.create!(path_index: "/docs/notifications", content: "文档正文")
    doc_thread = CommentThreadQuery.new.doc_id(doc.id).first
    doc_root = CreateComment.create!(user_id: parent_author.id, comment_thread_id: doc_thread.id, content: "文档评论")
    NotificationQuery.new.url("/comments/#{doc_root.id}").any?.should be_false
    doc_child = CreateComment.create!(user_id: responder.id, parent_id: doc_root.id, content: "文档子评论")
    notification = NotificationQuery.new.url("/comments/#{doc_child.id}").first
    notification.user_id.should eq(parent_author.id)
    notification.source_title.should eq("/docs/notifications")
    notification.excerpt.should eq("文档子评论")

    DocQuery.new.id(doc.id).update(content: nil)
    response = ApiClient.new.get(notification.url)
    response.status_code.should eq(404)
    response.body.should contain("评论已删除或暂不可见")
  end

  it "ignores code and email mentions, and notifies new mentions only once after editing" do
    author = UserFactory.create
    mentioned = UserFactory.create &.name("小明")
    added = UserFactory.create &.name("新朋友")
    code_user = UserFactory.create &.name("示例用户")
    thread = CommentThreadQuery.new.topic_id(notification_topic(author).id).first
    comment = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: <<-MARKDOWN)
      请@小明，看看这个例子。`@示例用户` 并不是提及。

      ```crystal
      @示例用户
      ```

      email@示例用户
      MARKDOWN

    NotificationQuery.new.url("/comments/#{comment.id}").results.map(&.user_id).should eq([mentioned.id])
    NotificationQuery.new.user_id(code_user.id).any?.should be_false
    NotificationQuery.new.user_id(mentioned.id).update(read_at: Time.utc)

    comment = UpdateComment.update!(comment, content: "@小明 @新朋友 @新朋友")
    UpdateComment.update!(comment, content: "@小明 @新朋友 再次编辑")
    NotificationQuery.new.url("/comments/#{comment.id}").select_count.should eq(2)
    NotificationQuery.new.user_id(mentioned.id).first.read_at.should_not be_nil
    NotificationQuery.new.user_id(added.id).first.kind.should eq(Notification::Kind::Mention)
  end

  it "supports mentions in topics and limits mention recipients" do
    author = UserFactory.create
    users = 7.times.map { |index| UserFactory.create &.name("被提及#{index}") }.to_a
    topic = notification_topic(author)
    topic = UpdateTopic.update!(topic, content: users.map { |user| "@#{user.name}" }.join(" "))
    NotificationQuery.new.url("/forum/#{topic.id}").select_count.should eq(5)
    UpdateTopic.update!(topic, content: "#{topic.content} 再次编辑")
    NotificationQuery.new.url("/forum/#{topic.id}").select_count.should eq(5)

    new_topic = CreateTopic.create!(user_id: author.id, node_id: topic.node_id, title: "提及", content: "@#{users.last.name}")
    notification = NotificationQuery.new.url("/forum/#{new_topic.id}").first
    notification.user_id.should eq(users.last.id)
    notification.actor_id.should eq(author.id)
    notification.source_title.should eq(new_topic.title)
    notification.excerpt.should eq(new_topic.content)
  end

  it "matches usernames exactly without stripping punctuation" do
    plain = UserFactory.create &.name("some.user")
    dotted = UserFactory.create &.name("some.user.")
    parentheses = UserFactory.create &.name("SomeUser(he/him)")
    UserMentions.user_ids("@SomeUser(he/him) @some.user.").should eq([dotted.id, parentheses.id])
    UserMentions.user_ids("@some.user").should eq([plain.id])
    UserMentions.user_ids("@some.user..").should be_empty
  end

  it "keeps historical snapshots but blocks navigation to hidden content" do
    author = UserFactory.create
    responder = UserFactory.create
    topic = notification_topic(author)
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "私有根评论")
    child = CreateComment.create!(user_id: responder.id, parent_id: root.id, content: "隐藏正文不能泄露")
    DeleteComment.delete!(root)

    notification = NotificationQuery.new.url("/comments/#{child.id}").first
    response = ApiClient.new.get("/notifications?backdoor_user_id=#{author.id}")
    response.status_code.should eq(200)
    response.body.should contain(topic.title)
    response.body.should contain(child.content)
    response.body.should contain(%(hx-boost="false"))
    response = ApiClient.new.get(notification.url)
    response.status_code.should eq(404)
    response.body.should contain("评论已删除或暂不可见")
    response.body.should_not contain(child.content)

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      response = ApiClient.new.post("/notifications/#{notification.id}/read?backdoor_user_id=#{author.id}")
      response.status_code.should eq(303)
      response.headers["Location"].should contain(notification.url)
      NotificationQuery.find(notification.id).read_at.should_not be_nil
    end

    CommentQuery.new.only_soft_deleted.id(root.id).first.restore
    ApiClient.new.get(notification.url).status_code.should eq(303)
    DeleteTopic.delete!(topic)
    ApiClient.new.get(notification.url).status_code.should eq(404)
    response = ApiClient.new.get("/forum/#{topic.id}")
    response.status_code.should eq(404)
    response.body.should contain("主题已删除或暂不可见")
  end

  it "retains URL snapshots after the target is physically deleted" do
    author = UserFactory.create
    responder = UserFactory.create
    topic = notification_topic(author)
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    comment = CreateComment.create!(user_id: responder.id, comment_thread_id: thread.id, content: "历史通知摘要")
    notification = NotificationQuery.new.url("/comments/#{comment.id}").first

    CommentQuery.new.id(comment.id).delete

    NotificationQuery.find(notification.id).excerpt.should eq(comment.content)
    response = ApiClient.new.get(notification.url)
    response.status_code.should eq(404)
    response.body.should contain("评论已删除或暂不可见")

    topic = UpdateTopic.update!(topic, content: "@#{responder.name}")
    notification = NotificationQuery.new.url("/forum/#{topic.id}").first

    TopicQuery.new.id(topic.id).delete

    NotificationQuery.find(notification.id).source_title.should eq(topic.title)
    response = ApiClient.new.get(notification.url)
    response.status_code.should eq(404)
    response.body.should contain("主题已删除或暂不可见")
  end

  it "captures escaped, character-limited snapshots and does not rewrite them after edits" do
    author = UserFactory.create
    responder = UserFactory.create
    topic = notification_topic(author)
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    content = %(<script>alert("snapshot")</script>) + "中文摘要" * 40
    comment = CreateComment.create!(user_id: responder.id, comment_thread_id: thread.id, content: content)
    notification = NotificationQuery.new.url("/comments/#{comment.id}").first

    notification.actor_id.should eq(responder.id)
    notification.source_title.should eq(topic.title)
    notification.excerpt.should eq(content[0, 120])
    notification.excerpt.size.should eq(120)

    UpdateUser.update!(responder, name: "新名字")
    UpdateTopic.update!(topic, title: "新主题标题", content: "编辑后的主题正文")
    UpdateComment.update!(comment, content: "编辑后的评论正文")
    notification = NotificationQuery.find(notification.id)
    notification.actor_id.should eq(responder.id)
    notification.source_title.should eq(topic.title)
    notification.excerpt.should eq(content[0, 120])

    response = ApiClient.new.get("/notifications?backdoor_user_id=#{author.id}")
    response.status_code.should eq(200)
    response.body.should contain("新名字")
    response.body.should contain("&lt;script&gt;")
    response.body.should_not contain(%(<script>alert("snapshot")</script>))
    response.body.should_not contain("编辑后的评论正文")

    DeleteComment.delete!(comment)
    ApiClient.new.get(notification.url).status_code.should eq(404)
    notification = SaveNotification.update!(notification, read_at: Time.utc)
    notification.excerpt.should eq(content[0, 120])
    notification.read_at.should_not be_nil
  end

  it "scopes read operations to the recipient and does not mark a list read automatically" do
    author = UserFactory.create
    responder = UserFactory.create
    thread = CommentThreadQuery.new.topic_id(notification_topic(author).id).first
    comment = CreateComment.create!(user_id: responder.id, comment_thread_id: thread.id, content: "回复")
    notification = NotificationQuery.new.url("/comments/#{comment.id}").first
    ApiClient.new.get("/notifications?backdoor_user_id=#{author.id}").status_code.should eq(200)
    NotificationQuery.find(notification.id).read_at.should be_nil

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      ApiClient.new.post("/notifications/#{notification.id}/read?backdoor_user_id=#{responder.id}").status_code.should eq(404)
      NotificationQuery.find(notification.id).read_at.should be_nil
      response = ApiClient.new.post("/notifications/#{notification.id}/read?backdoor_user_id=#{author.id}")
      response.status_code.should eq(303)
      response.headers["Location"].should contain("/comments/#{comment.id}")
      NotificationQuery.find(notification.id).read_at.should_not be_nil

      other = SaveNotification.create!(
        user_id: responder.id,
        actor_id: author.id,
        kind: Notification::Kind::Mention,
        url: notification.url,
        source_title: notification.source_title,
        excerpt: comment.content[0, 120]
      )
      ApiClient.new.post("/notifications/read_all?backdoor_user_id=#{author.id}").status_code.should eq(303)
      NotificationQuery.find(other.id).read_at.should be_nil
    end
  end

  it "locates root and child comments beyond the first page" do
    author = UserFactory.create
    responder = UserFactory.create
    thread = CommentThreadQuery.new.topic_id(notification_topic(author).id).first
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "要定位的根评论")
    child = CreateComment.create!(user_id: responder.id, parent_id: root.id, content: "要定位的子评论")
    11.times do |index|
      CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "较新根评论#{index}")
      CreateComment.create!(user_id: author.id, parent_id: root.id, content: "较新子评论#{index}")
    end

    root_response = ApiClient.new.get("/htmx/comments?comment_thread_id=#{thread.id}&comment_id=#{child.id}")
    root_response.status_code.should eq(200)
    root_response.body.should contain("要定位的根评论")
    root_response.body.should contain("正在定位评论")
    child_response = ApiClient.new.get("/htmx/comments?root_id=#{root.id}&comment_id=#{child.id}")
    child_response.status_code.should eq(200)
    child_response.body.should contain("要定位的子评论")
    child_response.body.should contain("scroll to the middle of me smoothly")
    [root, child].each do |comment|
      location = ApiClient.new.get("/comments/#{comment.id}").headers["Location"]
      location.should contain("?comment_id=#{comment.id}")
      URI.parse(location).fragment.should be_nil
    end
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
