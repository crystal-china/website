require "../spec_helper"

private def follow_test_topic(author : User) : Topic
  node = SaveNode.create!(name: "关注测试", slug: "topic-follows", summary: "测试", color: "#16a34a", position: 0)

  CreateTopic.create!(user_id: author.id, node_id: node.id, title: "关注主题测试", content: "主题正文")
end

describe "Topic follows" do
  around_each do |example|
    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      example.run
    end
  end

  it "creates the relationship indexes and cascading foreign keys, and rolls back the table" do
    AppDatabase.transaction do
      AppDatabase.exec "CREATE SCHEMA topic_follows_migration_spec"
      AppDatabase.exec "SET LOCAL search_path TO topic_follows_migration_spec"
      AppDatabase.exec "CREATE TABLE users (id bigint PRIMARY KEY)"
      AppDatabase.exec "CREATE TABLE topics (id bigint PRIMARY KEY)"
      migration = CreateTopicFollows::V20261022120000.new
      migration.migrate
      migration.prepared_statements.each { |statement| AppDatabase.exec(statement) }

      indexes = AppDatabase.query_all("SELECT indexdef FROM pg_indexes WHERE schemaname = 'topic_follows_migration_spec' AND tablename = 'topic_follows'", as: String)
      indexes.any? { |index| index.includes?("UNIQUE INDEX") && index.includes?("(topic_id, follower_id)") }.should be_true
      indexes.any?(&.includes?("(follower_id)")).should be_true

      AppDatabase.exec "INSERT INTO users VALUES (1), (2)"
      AppDatabase.exec "INSERT INTO topics VALUES (10)"
      AppDatabase.exec "INSERT INTO topic_follows (topic_id, follower_id) VALUES (10, 1), (10, 2)"
      AppDatabase.exec "DELETE FROM users WHERE id = 1"
      TopicFollowQuery.new.map(&.follower_id).should eq([2])
      AppDatabase.exec "DELETE FROM topics WHERE id = 10"
      TopicFollowQuery.new.any?.should be_false

      migration.reset_prepared_statements
      migration.rollback
      migration.prepared_statements.each { |statement| AppDatabase.exec(statement) }
      AppDatabase.query_one("SELECT count(*) FROM information_schema.tables WHERE table_schema = 'topic_follows_migration_spec' AND table_name = 'topic_follows'", as: Int64).should eq(0)

      AppDatabase.rollback
    end
  end

  it "shows the persisted follow state only to signed-in readers other than the author" do
    author = UserFactory.create
    reader = UserFactory.create
    topic = follow_test_topic(author)
    path = "/forum/#{topic.id}/follow"
    client = ApiClient.new

    ["", "?backdoor_user_id=#{author.id}"].each do |params|
      response = client.get("/forum/#{topic.id}#{params}")

      response.status_code.should eq(200)
      response.body.should_not contain(%(hx-post="#{path}"))
      response.body.should_not contain(%(hx-delete="#{path}"))
    end

    response = client.get("/forum/#{topic.id}?backdoor_user_id=#{reader.id}")
    button = XML.parse_html(response.body).xpath_node("//button[@hx-post='#{path}']").not_nil!
    button.content.should eq("关注")
    button["hx-target"].should eq("this")
    button["hx-swap"].should eq("outerHTML")
    TopicFollowQuery.new.any?.should be_false

    SaveTopicFollow.create!(topic_id: topic.id, follower_id: reader.id)
    response = client.get("/forum/#{topic.id}?backdoor_user_id=#{reader.id}&locale=en")
    XML.parse_html(response.body).xpath_node("//button[@hx-delete='#{path}']").not_nil!.content.should eq("Unfollow")
  end

  it "follows and unfollows idempotently using only the authenticated account" do
    author = UserFactory.create
    reader = UserFactory.create
    other = UserFactory.create
    topic = follow_test_topic(author)
    path = "/forum/#{topic.id}/follow?backdoor_user_id=#{reader.id}"
    client = ApiClient.new.headers("HX-Request-Type": "partial")

    2.times do
      response = client.post(path, follower_id: other.id)

      response.status_code.should eq(200)
      response.body.should contain("取消关注")
      response.body.should contain(%(hx-delete="/forum/#{topic.id}/follow"))
      response.body.should_not contain("<html")
    end

    TopicFollowQuery.new.select_count.should eq(1)
    TopicFollowQuery.new.first.follower_id.should eq(reader.id)
    SaveTopicFollow.create!(topic_id: topic.id, follower_id: other.id)

    2.times do
      response = client.delete(path, follower_id: other.id)

      response.status_code.should eq(200)
      response.body.should contain(%(hx-post="/forum/#{topic.id}/follow"))
    end

    TopicFollowQuery.new.topic_id(topic.id).map(&.follower_id).should eq([other.id])
  end

  it "requires login and rejects the author, missing topics and deleted topics" do
    author = UserFactory.create
    reader = UserFactory.create
    topic = follow_test_topic(author)
    path = "/forum/#{topic.id}/follow"
    client = ApiClient.new.headers("HX-Request-Type": "partial")

    client.post(path).status_code.should eq(401)
    client.delete(path).status_code.should eq(401)
    client.post("#{path}?backdoor_user_id=#{author.id}").status_code.should eq(403)
    client.delete("#{path}?backdoor_user_id=#{author.id}").status_code.should eq(403)
    client.post("/forum/0/follow?backdoor_user_id=#{reader.id}").status_code.should eq(404)
    client.delete("/forum/0/follow?backdoor_user_id=#{reader.id}").status_code.should eq(404)

    DeleteTopic.delete!(topic, actor_id: author.id)
    client.post("#{path}?backdoor_user_id=#{reader.id}").status_code.should eq(404)
    client.delete("#{path}?backdoor_user_id=#{reader.id}").status_code.should eq(404)
    TopicFollowQuery.new.any?.should be_false
  end

  it "notifies followers of root replies, child replies and deeper replies without notifying the sender" do
    author = UserFactory.create
    follower = UserFactory.create
    replier = UserFactory.create
    topic = follow_test_topic(author)
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    SaveTopicFollow.create!(topic_id: topic.id, follower_id: follower.id)
    SaveTopicFollow.create!(topic_id: topic.id, follower_id: replier.id)
    root = CreateComment.create!(user_id: replier.id, comment_thread_id: thread.id, content: "根回复")
    child = CreateComment.create!(user_id: replier.id, parent_id: root.id, content: "子回复")
    grandchild = CreateComment.create!(user_id: replier.id, parent_id: child.id, content: "更深一层回复")

    notifications = NotificationQuery.new.user_id(follower.id).id.asc_order.results
    notifications.map(&.url).should eq([root, child, grandchild].map { |comment| "/comments/#{comment.id}" })
    notifications.map(&.kind).uniq!.should eq([Notification::Kind::FollowedTopicReply])
    notifications.map(&.actor_id).uniq!.should eq([replier.id])
    notifications.first.source_title.should eq(topic.title)
    notifications.first.excerpt.should eq("根回复")
    NotificationQuery.new.user_id(replier.id).any?.should be_false
    TopicFollowQuery.new.select_count.should eq(2)

    response = ApiClient.new.get("/notifications?backdoor_user_id=#{follower.id}")
    response.body.should contain("回复了你关注的主题")
  end

  it "prioritizes mentions and direct replies over follows, including opted-out mention recipients" do
    author = UserFactory.create
    follower = UserFactory.create
    replier = UserFactory.create
    topic = follow_test_topic(author)
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    SaveTopicFollow.create!(topic_id: topic.id, follower_id: follower.id)
    root = CreateComment.create!(user_id: follower.id, comment_thread_id: thread.id, content: "我的回复")
    reply = CreateComment.create!(user_id: replier.id, parent_id: root.id, content: "直接回复")
    mentioned = CreateComment.create!(user_id: replier.id, parent_id: root.id, content: "@#{follower.login_name} 请看这里")
    follower = UpdateUser.update!(follower, mention_notifications_enabled: false)
    opted_out = CreateComment.create!(user_id: replier.id, comment_thread_id: thread.id, content: "@#{follower.login_name} 仍可收到关注通知")

    notifications = NotificationQuery.new.user_id(follower.id).id.asc_order.results
    notifications.map(&.url).should eq([reply, mentioned, opted_out].map { |comment| "/comments/#{comment.id}" })
    notifications.map(&.kind).should eq([
      Notification::Kind::CommentReply,
      Notification::Kind::Mention,
      Notification::Kind::FollowedTopicReply,
    ])
    NotificationQuery.new.user_id(author.id).url("/comments/#{reply.id}").first.kind.should eq(Notification::Kind::TopicReply)
  end

  it "preserves old notifications on unfollow and does not replay past replies on refollow" do
    author = UserFactory.create
    follower = UserFactory.create
    replier = UserFactory.create
    topic = follow_test_topic(author)
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    path = "/forum/#{topic.id}/follow?backdoor_user_id=#{follower.id}"
    client = ApiClient.new
    CreateComment.create!(user_id: replier.id, comment_thread_id: thread.id, content: "关注前的回复")

    client.post(path)
    NotificationQuery.new.user_id(follower.id).any?.should be_false
    first = CreateComment.create!(user_id: replier.id, comment_thread_id: thread.id, content: "关注后的回复")
    client.delete(path)
    CreateComment.create!(user_id: replier.id, comment_thread_id: thread.id, content: "取消关注后的回复")
    client.post(path)
    NotificationQuery.new.user_id(follower.id).select_count.should eq(1)
    second = CreateComment.create!(user_id: replier.id, comment_thread_id: thread.id, content: "再次关注后的回复")

    NotificationQuery.new.user_id(follower.id).id.asc_order.map(&.url).should eq([first, second].map { |comment| "/comments/#{comment.id}" })
  end

  it "deduplicates repeated deliveries and allows a later mention after a follow notification" do
    author = UserFactory.create
    follower = UserFactory.create
    replier = UserFactory.create
    topic = follow_test_topic(author)
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    SaveTopicFollow.create!(topic_id: topic.id, follower_id: follower.id)
    comment = CreateComment.create!(user_id: replier.id, comment_thread_id: thread.id, content: "新回复")

    2.times { NotificationDelivery.comment_created(comment, [] of String) }
    NotificationQuery.new.user_id(follower.id).select_count.should eq(1)
    UpdateComment.update!(comment, content: "@#{follower.login_name} 编辑补充", actor_id: replier.id)

    NotificationQuery.new.user_id(follower.id).id.asc_order.map(&.kind).should eq([
      Notification::Kind::FollowedTopicReply,
      Notification::Kind::Mention,
    ])
  end

  it "does not notify followers about edits, deletions, restores or document comments" do
    author = UserFactory.create
    follower = UserFactory.create
    topic = follow_test_topic(author)
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    SaveTopicFollow.create!(topic_id: topic.id, follower_id: follower.id)
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "原回复")
    topic = UpdateTopic.update!(topic, content: "编辑主题", actor_id: author.id)
    root = UpdateComment.update!(root, content: "编辑回复", actor_id: author.id)
    DeleteComment.delete!(root, actor_id: author.id)
    CommentQuery.new.only_soft_deleted.id(root.id).first.restore
    DeleteTopic.delete!(topic, actor_id: author.id)
    topic = TopicQuery.new.only_soft_deleted.id(topic.id).first.restore
    doc = SaveDoc.create!(path_index: "/docs/follow-test", content: "文档")
    doc_thread = CommentThreadQuery.new.doc_id(doc.id).first
    CreateComment.create!(user_id: author.id, comment_thread_id: doc_thread.id, content: "文档评论")

    NotificationQuery.new.user_id(follower.id).select_count.should eq(1)
    TopicFollowQuery.new.topic_id(topic.id).follower_id(follower.id).any?.should be_true
    CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "恢复后的新回复")
    NotificationQuery.new.user_id(follower.id).select_count.should eq(2)
  end

  it "rolls back follower notifications with a failed comment transaction" do
    author = UserFactory.create
    follower = UserFactory.create
    topic = follow_test_topic(author)
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    SaveTopicFollow.create!(topic_id: topic.id, follower_id: follower.id)

    AppDatabase.transaction do
      CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "需要回滚的回复")
      NotificationQuery.new.user_id(follower.id).select_count.should eq(1)
      AppDatabase.rollback
    end

    CommentQuery.new.any?.should be_false
    NotificationQuery.new.any?.should be_false
  end
end
