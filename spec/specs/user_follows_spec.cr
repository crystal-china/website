require "../spec_helper"

private def user_follow_topic(author : User, content : String = "主题正文") : Topic
  node = NodeQuery.new.slug("user-follows").first? ||
         SaveNode.create!(name: "用户关注测试", slug: "user-follows", summary: "测试", color: "#16a34a", position: 0)

  CreateTopic.create!(user_id: author.id, node_id: node.id, title: "用户关注主题", content: content)
end

describe "User follows" do
  around_each do |example|
    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      example.run
    end
  end

  it "enforces unique relationships, rejects self follows, cascades account deletion and rolls back the table" do
    AppDatabase.transaction do
      AppDatabase.exec "CREATE SCHEMA user_follows_migration_spec"
      AppDatabase.exec "SET LOCAL search_path TO user_follows_migration_spec"
      AppDatabase.exec "CREATE TABLE users (id bigint PRIMARY KEY)"
      migration = CreateUserFollows::V20261102120000.new
      migration.migrate
      migration.prepared_statements.each { |statement| AppDatabase.exec(statement) }

      indexes = AppDatabase.query_all("SELECT indexdef FROM pg_indexes WHERE schemaname = 'user_follows_migration_spec' AND tablename = 'user_follows'", as: String)
      indexes.any? { |index| index.includes?("UNIQUE INDEX") && index.includes?("(followed_user_id, follower_id)") }.should be_true
      indexes.any?(&.includes?("(follower_id)")).should be_true

      AppDatabase.exec "INSERT INTO users VALUES (1), (2), (3)"
      AppDatabase.exec "INSERT INTO user_follows (followed_user_id, follower_id) VALUES (1, 2), (1, 3)"
      AppDatabase.exec "DELETE FROM users WHERE id = 2"
      UserFollowQuery.new.map(&.follower_id).should eq([3])
      AppDatabase.exec "DELETE FROM users WHERE id = 1"
      UserFollowQuery.new.any?.should be_false
      constraint = AppDatabase.query_one("SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid = 'user_follows'::regclass AND conname = 'user_follows_followed_user_id_follower_id_different_check'", as: String)
      constraint.should contain("followed_user_id <> follower_id")

      migration.reset_prepared_statements
      migration.drop_different_values(
        table_name: "user_follows",
        left_column: "followed_user_id",
        right_column: "follower_id"
      )
      migration.prepared_statements.each { |statement| AppDatabase.exec(statement) }
      AppDatabase.exec "INSERT INTO user_follows (followed_user_id, follower_id) VALUES (3, 3)"
      UserFollowQuery.new.followed_user_id(3).follower_id(3).any?.should be_true

      migration.reset_prepared_statements
      migration.rollback
      migration.prepared_statements.each { |statement| AppDatabase.exec(statement) }
      AppDatabase.query_one("SELECT count(*) FROM information_schema.tables WHERE table_schema = 'user_follows_migration_spec' AND table_name = 'user_follows'", as: Int64).should eq(0)

      AppDatabase.rollback
    end

    user = UserFactory.create
    SaveUserFollow.create(followed_user_id: user.id, follower_id: user.id) do |operation, follow|
      follow.should be_nil
      operation.follower_id.errors.should contain("不能关注自己")
    end
  end

  it "uses the authenticated follower, is idempotent, and rejects guests, self follows and missing users" do
    author = UserFactory.create
    reader = UserFactory.create
    other = UserFactory.create
    client = ApiClient.new.headers("HX-Request-Type": "partial")
    path = "/users/#{author.id}/follow?backdoor_user_id=#{reader.id}"

    client.post("/users/#{author.id}/follow").status_code.should eq(401)
    client.delete("/users/#{author.id}/follow").status_code.should eq(401)
    client.post("/users/#{reader.id}/follow?backdoor_user_id=#{reader.id}").status_code.should eq(403)
    client.delete("/users/#{reader.id}/follow?backdoor_user_id=#{reader.id}").status_code.should eq(403)
    client.post("/users/0/follow?backdoor_user_id=#{reader.id}").status_code.should eq(404)
    client.delete("/users/0/follow?backdoor_user_id=#{reader.id}").status_code.should eq(404)

    2.times do
      response = client.post(path, follower_id: other.id, followed_user_id: other.id)

      response.status_code.should eq(200)
      response.body.should contain(%(hx-delete="/users/#{author.id}/follow"))
      response.body.should_not contain("<html")
    end

    UserFollowQuery.new.map { |follow| {follow.followed_user_id, follow.follower_id} }.should eq([{author.id, reader.id}])
    SaveUserFollow.create!(followed_user_id: author.id, follower_id: other.id)

    2.times do
      response = client.delete(path, follower_id: other.id)

      response.status_code.should eq(200)
      response.body.should contain(%(hx-post="/users/#{author.id}/follow"))
    end

    UserFollowQuery.new.followed_user_id(author.id).map(&.follower_id).should eq([other.id])
    NotificationQuery.new.any?.should be_false
  end

  it "shows persisted follow state on profiles without replacing existing owner and administrator actions" do
    admin_emails = ENV["ADMIN_EMAILS"]?
    author = UserFactory.create
    reader = UserFactory.create
    admin = UserFactory.create
    path = "/users/#{author.id}/follow"
    profile = "/users/#{author.login_name}/profile"
    client = ApiClient.new

    ["", "?backdoor_user_id=#{author.id}"].each do |params|
      response = client.get("#{profile}#{params}")

      response.status_code.should eq(200)
      response.body.should_not contain(%(hx-post="#{path}"))
      response.body.should_not contain(%(hx-delete="#{path}"))
    end

    response = client.get("#{profile}?backdoor_user_id=#{reader.id}")
    button = XML.parse_html(response.body).xpath_node("//button[@hx-post='#{path}']").not_nil!
    button.content.should eq("关注")
    button["hx-target"].should eq("this")
    button["hx-swap"].should eq("outerHTML")
    SaveUserFollow.create!(followed_user_id: author.id, follower_id: reader.id)
    author = UpdateUser.update!(author, nickname: "新昵称", login_name: "renamed_author")
    response = client.get("/users/#{author.login_name}/profile?backdoor_user_id=#{reader.id}&locale=en")
    XML.parse_html(response.body).xpath_node("//button[@hx-delete='#{path}']").not_nil!.content.should eq("Unfollow")

    ENV["ADMIN_EMAILS"] = admin.email
    response = client.get("/users/#{author.login_name}/profile?backdoor_user_id=#{admin.id}")
    document = XML.parse_html(response.body)
    document.xpath_node("//button[@hx-post='#{path}']").should_not be_nil
    document.xpath_node("//a[@href='/users/#{author.id}/edit']").should_not be_nil
    document.xpath_node("//a[@href='/user_audits?user_id=#{author.id}']").should_not be_nil
  ensure
    if admin_emails
      ENV["ADMIN_EMAILS"] = admin_emails
    else
      ENV.delete("ADMIN_EMAILS")
    end
  end

  it "shows the author follow state in the topic sidebar and hides the button for guests and the author" do
    author = UserFactory.create
    reader = UserFactory.create
    topic = user_follow_topic(author)
    path = "/users/#{author.id}/follow"
    client = ApiClient.new

    ["", "?backdoor_user_id=#{author.id}"].each do |params|
      response = client.get("/forum/#{topic.id}#{params}")

      response.status_code.should eq(200)
      response.body.should_not contain(%(hx-post="#{path}"))
      response.body.should_not contain(%(hx-delete="#{path}"))
    end

    response = client.get("/forum/#{topic.id}?backdoor_user_id=#{reader.id}")
    document = XML.parse_html(response.body)

    response.status_code.should eq(200)
    document.xpath_node("//aside//button[@hx-post='#{path}']").not_nil!.content.should eq("关注")

    client.post("#{path}?backdoor_user_id=#{reader.id}")
    response = client.get("/forum/#{topic.id}?backdoor_user_id=#{reader.id}")
    document = XML.parse_html(response.body)

    document.xpath_node("//aside//button[@hx-delete='#{path}']").not_nil!.content.should eq("取消关注")

    client.delete("#{path}?backdoor_user_id=#{reader.id}")
    response = client.get("/forum/#{topic.id}?backdoor_user_id=#{reader.id}")
    document = XML.parse_html(response.body)

    document.xpath_node("//aside//button[@hx-post='#{path}']").not_nil!.content.should eq("关注")
  end

  it "notifies followers of new topics with mention precedence and allows a later mention after a follow notification" do
    author = UserFactory.create
    follower = UserFactory.create
    mentioned = UserFactory.create
    opted_out = UserFactory.create &.mention_notifications_enabled(false)

    [follower, mentioned, opted_out].each do |user|
      SaveUserFollow.create!(followed_user_id: author.id, follower_id: user.id)
    end

    topic = user_follow_topic(author, "@#{mentioned.login_name} @#{opted_out.login_name} @#{author.login_name} 新主题")
    notifications = NotificationQuery.new.url("/forum/#{topic.id}").results.to_h { |notification| {notification.user_id, notification} }
    notifications.size.should eq(4)
    notifications[follower.id].kind.should eq(Notification::Kind::FollowedUserTopic)
    notifications[mentioned.id].kind.should eq(Notification::Kind::Mention)
    notifications[opted_out.id].kind.should eq(Notification::Kind::FollowedUserTopic)
    notifications[author.id].kind.should eq(Notification::Kind::Mention)
    notifications[follower.id].actor_id.should eq(author.id)
    notifications[follower.id].source_title.should eq(topic.title)
    NotificationDelivery.topic_created(topic, [mentioned.login_name, opted_out.login_name, author.login_name])
    NotificationQuery.new.url("/forum/#{topic.id}").select_count.should eq(4)
    UpdateTopic.update!(topic, content: "@#{follower.login_name} 编辑补充", actor_id: author.id)
    NotificationQuery.new.user_id(follower.id).id.asc_order.map(&.kind).should eq([
      Notification::Kind::FollowedUserTopic,
      Notification::Kind::Mention,
    ])

    ApiClient.new.get("/notifications?backdoor_user_id=#{opted_out.id}").body.should contain("发布了新主题")
  end

  it "prioritizes mentions, direct replies, topic owners and topic follows over user follows" do
    owner = UserFactory.create
    author = UserFactory.create
    parent_author = UserFactory.create
    topic_follower = UserFactory.create
    user_follower = UserFactory.create
    mentioned = UserFactory.create
    topic = user_follow_topic(owner)
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    root = CreateComment.create!(user_id: parent_author.id, comment_thread_id: thread.id, content: "根评论")

    [owner, parent_author, topic_follower, user_follower, mentioned].each do |user|
      SaveUserFollow.create!(followed_user_id: author.id, follower_id: user.id)
    end

    SaveTopicFollow.create!(topic_id: topic.id, follower_id: topic_follower.id)
    SaveTopicFollow.create!(topic_id: topic.id, follower_id: author.id)
    child = CreateComment.create!(user_id: author.id, parent_id: root.id, content: "@#{mentioned.login_name} 新回复")
    recipients = NotificationQuery.new.url("/comments/#{child.id}").results.to_h { |notification| {notification.user_id, notification.kind} }

    recipients.should eq({
      owner.id          => Notification::Kind::TopicReply,
      parent_author.id  => Notification::Kind::CommentReply,
      topic_follower.id => Notification::Kind::FollowedTopicReply,
      user_follower.id  => Notification::Kind::FollowedUserReply,
      mentioned.id      => Notification::Kind::Mention,
    })
    NotificationDelivery.comment_created(child, [mentioned.login_name])
    NotificationQuery.new.url("/comments/#{child.id}").select_count.should eq(5)
    grandchild = CreateComment.create!(user_id: author.id, parent_id: child.id, content: "更深回复")
    NotificationQuery.new.user_id(user_follower.id).url("/comments/#{grandchild.id}").first.kind.should eq(Notification::Kind::FollowedUserReply)
    doc = SaveDoc.create!(path_index: "/docs/user-follows", content: "文档")
    doc_thread = CommentThreadQuery.new.doc_id(doc.id).first
    doc_comment = CreateComment.create!(user_id: author.id, comment_thread_id: doc_thread.id, content: "文档评论")
    NotificationQuery.new.user_id(user_follower.id).url("/comments/#{doc_comment.id}").first.source_title.should eq(doc.path_index)
    NotificationQuery.new.user_id(author.id).any?.should be_false
    ApiClient.new.get("/notifications?backdoor_user_id=#{user_follower.id}").body.should contain("发表了评论")
  end

  it "keeps history on unfollow, does not replay activity on refollow, and rolls back new activity notifications" do
    author = UserFactory.create
    follower = UserFactory.create
    client = ApiClient.new
    path = "/users/#{author.id}/follow?backdoor_user_id=#{follower.id}"

    user_follow_topic(author)
    client.post(path)
    NotificationQuery.new.user_id(follower.id).any?.should be_false
    first = user_follow_topic(author)
    client.delete(path)
    user_follow_topic(author)
    client.post(path)
    NotificationQuery.new.user_id(follower.id).map(&.url).should eq(["/forum/#{first.id}"])

    AppDatabase.transaction do
      user_follow_topic(author)
      NotificationQuery.new.user_id(follower.id).select_count.should eq(2)
      AppDatabase.rollback
    end

    NotificationQuery.new.user_id(follower.id).select_count.should eq(1)
    second = user_follow_topic(author)
    NotificationQuery.new.user_id(follower.id).id.asc_order.map(&.url).should eq(["/forum/#{first.id}", "/forum/#{second.id}"])
  end

  it "does not send follow notifications for edits, administration, withdrawal, deletion or restoration" do
    author = UserFactory.create
    follower = UserFactory.create
    editor = UserFactory.create
    SaveUserFollow.create!(followed_user_id: author.id, follower_id: follower.id)
    SaveUserFollow.create!(followed_user_id: editor.id, follower_id: follower.id)
    topic = user_follow_topic(author)
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    comment = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "原评论")
    topic = UpdateTopic.update!(topic, content: "作者编辑", actor_id: author.id)
    topic = UpdateTopic.update!(topic, content: "管理员编辑", actor_id: editor.id)
    comment = UpdateComment.update!(comment, content: "管理员编辑评论", actor_id: editor.id)
    comment = Comment::SaveOperation.update!(comment, withdrawn: true)
    comment = Comment::SaveOperation.update!(comment, withdrawn: false)
    DeleteComment.delete!(comment, actor_id: editor.id)
    CommentQuery.new.only_soft_deleted.id(comment.id).first.restore
    DeleteTopic.delete!(topic, actor_id: editor.id)
    TopicQuery.new.only_soft_deleted.id(topic.id).first.restore

    NotificationQuery.new.user_id(follower.id).id.asc_order.map(&.url).should eq(["/forum/#{topic.id}", "/comments/#{comment.id}"])
  end
end
