require "../spec_helper"
require "timecop"

private def topic_read_node : Node
  SaveNode.create!(name: "未读测试", slug: "topic-reads", summary: "测试", color: "#0284c7", position: 0)
end

private def topic_read_topic(author : User, node : Node, title : String = "未读主题") : Topic
  CreateTopic.create!(user_id: author.id, node_id: node.id, title: title, content: "主题正文")
end

private def topic_read_notification(
  user : User,
  actor : User,
  *,
  topic_id : Int64? = nil,
  comment_id : Int64? = nil,
  read_at : Time? = nil,
) : Notification
  SaveNotification.create!(
    user_id: user.id,
    actor_id: actor.id,
    topic_id: topic_id,
    comment_id: comment_id,
    kind: :mention,
    source_title: "阅读同步测试",
    excerpt: "通知摘要",
    read_at: read_at
  )
end

describe "Topic reads" do
  it "creates indexed read records with cascading deletes and rolls back" do
    AppDatabase.transaction do
      AppDatabase.exec "CREATE SCHEMA topic_reads_migration_spec"
      AppDatabase.exec "SET LOCAL search_path TO topic_reads_migration_spec"
      AppDatabase.exec "CREATE TABLE users (id bigint PRIMARY KEY)"
      AppDatabase.exec "CREATE TABLE topics (id bigint PRIMARY KEY)"
      AppDatabase.exec "INSERT INTO users VALUES (1), (2)"
      AppDatabase.exec "INSERT INTO topics VALUES (10)"

      reads_migration = CreateTopicReads::V20261103121000.new
      reads_migration.migrate
      reads_migration.prepared_statements.each { |statement| AppDatabase.exec(statement) }
      indexes = AppDatabase.query_all("SELECT indexdef FROM pg_indexes WHERE schemaname = 'topic_reads_migration_spec' AND tablename = 'topic_reads'", as: String)

      indexes.any? { |index| index.includes?("UNIQUE INDEX") && index.includes?("(topic_id, user_id)") }.should be_true
      indexes.any?(&.includes?("(user_id)")).should be_true
      TopicReading.mark_as_read(topic_id: 10_i64, user_id: 1_i64, last_reply_id: 101_i64)
      TopicReading.mark_as_read(topic_id: 10_i64, user_id: 2_i64, last_reply_id: 101_i64)
      AppDatabase.exec "DELETE FROM users WHERE id = 1"
      TopicReadQuery.new.select_count.should eq(1)
      AppDatabase.exec "DELETE FROM topics WHERE id = 10"
      TopicReadQuery.new.any?.should be_false

      reads_migration.reset_prepared_statements
      reads_migration.rollback
      reads_migration.prepared_statements.each { |statement| AppDatabase.exec(statement) }
      AppDatabase.query_one("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'topic_reads_migration_spec' AND table_name = 'topic_reads'", as: Int64).should eq(0)

      AppDatabase.rollback
    end
  end

  it "limits the unread filter to seven days of activity but keeps unread markers on older topics" do
    author = UserFactory.create
    reader = UserFactory.create
    node = topic_read_node
    recent = topic_read_topic(author, node, "旧主题近期活跃")
    boundary = topic_read_topic(author, node, "七天边界")
    expired = topic_read_topic(author, node, "超过七天")
    now = Time.utc(2026, 10, 27, 12)
    cutoff = now - 7.days

    TopicQuery.new.id(recent.id).update(created_at: now - 30.days, last_active_at: cutoff + 1.microsecond)
    TopicQuery.new.id(boundary.id).update(last_active_at: cutoff)
    TopicQuery.new.id(expired.id).update(last_active_at: cutoff - 1.microsecond)

    Timecop.freeze(now) do
      topic_ids = [recent.id, boundary.id, expired.id]

      TopicQuery.new.unread_by(reader.id).id.asc_order.map(&.id).should eq(topic_ids)
      TopicReading.unread_ids(user_id: reader.id, topic_ids: topic_ids).should eq(topic_ids.to_set)

      response = ApiClient.new.get("/forum?only_show_unread=true&backdoor_user_id=#{reader.id}")
      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      document.xpath_nodes("//section[@id='forum-topics']//h2/a").map(&.content).should eq([recent.title, boundary.title])
    end

    Timecop.freeze(now + 1.microsecond) do
      response = ApiClient.new.get("/forum?only_show_unread=true&backdoor_user_id=#{reader.id}")
      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      document.xpath_nodes("//section[@id='forum-topics']//h2/a").map(&.content).should eq([recent.title])

      response = ApiClient.new.get("/forum?backdoor_user_id=#{reader.id}")
      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      document.xpath_nodes("//section[@id='forum-topics']//h2/span[@title='未读']").size.should eq(3)

      TopicReading.mark_as_read(topic_id: expired.id, user_id: reader.id, last_reply_id: nil)

      TopicReading.unread_ids(user_id: reader.id, topic_ids: [expired.id]).should be_empty
    end
  end

  it "marks successful topic views as read per account without changing follows, notification history, or the topic" do
    author = UserFactory.create
    reader = UserFactory.create
    other = UserFactory.create
    topic = topic_read_topic(author, topic_read_node)
    original_updated_at = topic.updated_at
    notices = NotificationQuery.new.select_count
    path = "/forum/#{topic.id}"

    TopicReadQuery.new.user_id(author.id).topic_id(topic.id).first.last_read_reply_id.should eq(0)
    ApiClient.new.get(path).status_code.should eq(200)
    TopicReadQuery.new.user_id(reader.id).any?.should be_false

    2.times do
      ApiClient.new.get("#{path}?backdoor_user_id=#{reader.id}&user_id=#{other.id}").status_code.should eq(200)
    end

    TopicReadQuery.new.user_id(reader.id).select_count.should eq(1)
    TopicReadQuery.new.user_id(reader.id).first.last_read_reply_id.should eq(0)
    TopicQuery.new.unread_by(reader.id).id(topic.id).any?.should be_false
    TopicQuery.new.unread_by(other.id).id(topic.id).any?.should be_true
    TopicFollowQuery.new.any?.should be_false
    NotificationQuery.new.select_count.should eq(notices)
    topic.reload.updated_at.should eq(original_updated_at)

    DeleteTopic.delete!(topic)
    ApiClient.new.get("#{path}?backdoor_user_id=#{other.id}").status_code.should eq(404)
    TopicReadQuery.new.user_id(other.id).any?.should be_false
  end

  it "marks related notifications read on a topic visit and renders the updated bell without affecting other targets or users" do
    author = UserFactory.create
    reader = UserFactory.create
    other = UserFactory.create
    node = topic_read_node
    topic = topic_read_topic(author, node)
    another_topic = topic_read_topic(author, node, "另一个主题")
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "根回复")
    child = ReplyToComment.create!(user_id: author.id, parent_id: root.id, content: "子回复")
    doc = SaveDoc.create!(path_index: "/docs/read-notifications", content: "文档")
    doc_thread = CommentThreadQuery.new.doc_id(doc.id).first
    doc_comment = CreateComment.create!(user_id: author.id, comment_thread_id: doc_thread.id, content: "文档评论")
    related = [
      topic_read_notification(reader, author, topic_id: topic.id),
      topic_read_notification(reader, author, topic_id: topic.id, comment_id: root.id),
      topic_read_notification(reader, author, topic_id: topic.id, comment_id: child.id),
    ]
    unrelated = [
      topic_read_notification(reader, author, topic_id: another_topic.id),
      topic_read_notification(reader, author, comment_id: doc_comment.id),
      topic_read_notification(other, author, topic_id: topic.id),
    ]
    already_read = topic_read_notification(reader, author, topic_id: topic.id, read_at: Time.utc - 1.day)

    ApiClient.new.get("/forum/#{topic.id}").status_code.should eq(200)
    related.each(&.reload.read_at.should(be_nil))

    response = ApiClient.new.get("/forum/#{topic.id}?backdoor_user_id=#{reader.id}")
    document = XML.parse_html(response.body)
    current = reader.reload

    response.status_code.should eq(200)
    related.each(&.reload.read_at.should_not(be_nil))
    unrelated.each(&.reload.read_at.should(be_nil))
    already_read.reload.read_at.should eq(already_read.read_at)
    {current.notifications_count, current.unread_notifications_count}.should eq({6, 2})
    document.xpath_node("//*[@id='notification-status']//span[@aria-hidden='true']").not_nil!.content.should eq("2")
    TopicReadQuery.new.user_id(reader.id).topic_id(topic.id).first.last_read_reply_id.should eq(child.id)
    topic.reload.updated_at.should eq(topic.updated_at)
  end

  it "only clears notifications covered by the topic reply snapshot" do
    author = UserFactory.create
    reader = UserFactory.create
    topic = topic_read_topic(author, topic_read_node)
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "旧回复")
    child = ReplyToComment.create!(user_id: author.id, parent_id: root.id, content: "之后新增的回复")
    topic_notice = topic_read_notification(reader, author, topic_id: topic.id)
    old_notice = topic_read_notification(reader, author, topic_id: topic.id, comment_id: root.id)
    new_notice = topic_read_notification(reader, author, topic_id: topic.id, comment_id: child.id)

    NotificationQuery.new.user_id(reader.id)
      .unread_in_topic(topic.id, last_read_reply_id: nil)
      .update(read_at: Time.utc).should eq(1)
    topic_notice.reload.read_at.should_not be_nil
    old_notice.reload.read_at.should be_nil
    new_notice.reload.read_at.should be_nil

    NotificationQuery.new.user_id(reader.id)
      .unread_in_topic(topic.id, last_read_reply_id: root.id)
      .update(read_at: Time.utc).should eq(1)
    old_notice.reload.read_at.should_not be_nil
    new_notice.reload.read_at.should be_nil
    reader.reload.unread_notifications_count.should eq(1)
  end

  it "reads the topic after following a notification, but does not read topics when dismissing all notifications" do
    author = UserFactory.create
    reader = UserFactory.create
    topic = topic_read_topic(author, topic_read_node)
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    root = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "@#{reader.login_name} 回复")
    notification = NotificationQuery.new.user_id(reader.id).for_target(root).first
    topic_notice = topic_read_notification(reader, author, topic_id: topic.id)
    client = ApiClient.new

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      response = client.post("/notifications/#{notification.id}/read?backdoor_user_id=#{reader.id}")

      response.status_code.should eq(303)
      TopicReadQuery.new.user_id(reader.id).any?.should be_false

      response = client.get("#{response.headers["Location"]}?backdoor_user_id=#{reader.id}")

      response.status_code.should eq(303)

      response = client.get("#{response.headers["Location"]}&backdoor_user_id=#{reader.id}")

      response.status_code.should eq(200)
      topic_notice.reload.read_at.should_not be_nil
      TopicQuery.new.unread_by(reader.id).id(topic.id).any?.should be_false
      XML.parse_html(response.body).xpath_node("//*[@id='notification-status']//span[@aria-hidden='true']").should be_nil

      child = ReplyToComment.create!(user_id: author.id, parent_id: root.id, content: "@#{reader.login_name} 新回复")

      TopicQuery.new.unread_by(reader.id).id(topic.id).any?.should be_true
      client.post("/notifications/read_all?backdoor_user_id=#{reader.id}").status_code.should eq(200)
      NotificationQuery.new.user_id(reader.id).for_target(child).first.read_at.should_not be_nil
      TopicQuery.new.unread_by(reader.id).id(topic.id).any?.should be_true
      TopicReadQuery.new.user_id(reader.id).topic_id(topic.id).first.last_read_reply_id.should eq(root.id)
    end
  end

  it "tracks root and nested replies, keeps the sender read, and does not move read positions backwards" do
    author = UserFactory.create
    reader = UserFactory.create
    sender = UserFactory.create
    topic = topic_read_topic(author, topic_read_node)
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    path = "/forum/#{topic.id}?backdoor_user_id=#{reader.id}"
    client = ApiClient.new

    client.get(path)
    root = CreateComment.create!(user_id: sender.id, comment_thread_id: thread.id, content: "根回复")
    topic.reload.last_reply_id.should eq(root.id)
    TopicQuery.new.unread_by(reader.id).id(topic.id).any?.should be_true
    TopicQuery.new.unread_by(sender.id).id(topic.id).any?.should be_false
    client.get(path)
    child = ReplyToComment.create!(user_id: sender.id, parent_id: root.id, content: "子回复")
    topic.reload.last_reply_id.should eq(child.id)
    TopicQuery.new.unread_by(reader.id).id(topic.id).any?.should be_true
    client.get(path)

    TopicReading.mark_as_read(topic_id: topic.id, user_id: reader.id, last_reply_id: root.id)
    TopicReadQuery.new.user_id(reader.id).topic_id(topic.id).first.last_read_reply_id.should eq(child.id)
    TopicQuery.new.unread_by(reader.id).id(topic.id).any?.should be_false
    updated_at = topic.reload.updated_at

    DeleteComment.delete!(child)
    topic.reload.last_reply_id.should eq(root.id)
    TopicQuery.new.unread_by(reader.id).id(topic.id).any?.should be_false
    CommentQuery.new.only_soft_deleted.id(child.id).first.restore
    topic.reload.last_reply_id.should eq(child.id)
    TopicQuery.new.unread_by(reader.id).id(topic.id).any?.should be_false
    topic.updated_at.should eq(updated_at)

    grandchild = ReplyToComment.create!(user_id: sender.id, parent_id: child.id, content: "孙回复")

    TopicQuery.new.unread_by(reader.id).id(topic.id).any?.should be_true

    AppDatabase.transaction do
      own_reply = ReplyToComment.create!(user_id: reader.id, parent_id: grandchild.id, content: "需要回滚的回复")

      TopicReadQuery.new.user_id(reader.id).topic_id(topic.id).first.last_read_reply_id.should eq(own_reply.id)
      AppDatabase.rollback
    end

    TopicReadQuery.new.user_id(reader.id).topic_id(topic.id).first.last_read_reply_id.should eq(child.id)
    topic.reload.last_reply_id.should eq(grandchild.id)
  end

  it "leaves editing, voting, withdrawal, and document comments out of topic unread activity" do
    author = UserFactory.create
    reader = UserFactory.create
    topic = topic_read_topic(author, topic_read_node)
    thread = CommentThreadQuery.new.topic_id(topic.id).first
    comment = CreateComment.create!(user_id: author.id, comment_thread_id: thread.id, content: "回复")
    client = ApiClient.new

    client.get("/forum/#{topic.id}?backdoor_user_id=#{reader.id}")
    read = TopicReadQuery.new.user_id(reader.id).topic_id(topic.id).first
    last_read_at = read.last_read_at

    UpdateTopic.update!(topic, title: "修改标题", content: "修改正文", actor_id: author.id)
    UpdateComment.update!(comment, content: "修改回复", actor_id: author.id)
    comment = Comment::SaveOperation.update!(comment, withdrawn: true)
    comment = Comment::SaveOperation.update!(comment, withdrawn: false)

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      client.patch("/htmx/vote?backdoor_user_id=#{reader.id}", comment_id: comment.id, vote_type: "👍").status_code.should eq(200)
    end

    TopicQuery.new.unread_by(reader.id).id(topic.id).any?.should be_false
    read.reload.last_read_at.should eq(last_read_at)
    count = TopicReadQuery.new.select_count
    doc = SaveDoc.create!(path_index: "/docs/topic-read-test", content: "文档正文")
    doc_thread = CommentThreadQuery.new.doc_id(doc.id).first
    CreateComment.create!(user_id: reader.id, comment_thread_id: doc_thread.id, content: "文档评论")
    TopicReadQuery.new.select_count.should eq(count)
  end

  it "requires login for the unread filter and translates empty states without exposing account state to guests" do
    reader = UserFactory.create
    client = ApiClient.new
    response = client.get("/forum?only_show_unread=true")

    response.status_code.should eq(303)
    response.headers["Location"].should eq(SignIns::New.path)
    client.headers("HX-Request-Type": "partial").get("/forum?only_show_unread=true").status_code.should eq(401)

    {"zh-CN" => "没有符合条件的未读主题", "en" => "No unread topics here"}.each do |locale, message|
      response = ApiClient.new.get("/forum?only_show_unread=true&locale=#{locale}&backdoor_user_id=#{reader.id}")
      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      document.xpath_node("//section[@id='forum-topics']").not_nil!.content.should contain(message)
      document.xpath_node("//section[@id='forum-topics']//nav").should be_nil
    end
  end

  it "combines unread, following, and nodes, preserves filters through topic views, and keeps canonical URLs clean" do
    author = UserFactory.create
    reader = UserFactory.create
    node = topic_read_node
    other_node = SaveNode.create!(name: "其他节点", slug: "other-topic-read", summary: "测试", color: "#0284c7", position: 0)
    topic = topic_read_topic(author, node, "关注且未读")
    topic_read_topic(author, node, "未关注")
    outside = topic_read_topic(author, other_node, "其他节点")
    [topic, outside].each { |record| SaveTopicFollow.create!(topic_id: record.id, follower_id: reader.id) }
    path = "/forum?node=#{node.slug}&following=true&only_show_unread=true&backdoor_user_id=#{reader.id}"
    response = ApiClient.new.get(path)
    document = XML.parse_html(response.body)
    list = document.xpath_node("//section[@id='forum-topics']").not_nil!
    topic_path = list.xpath_node(".//h2/a").not_nil!["href"]

    list.xpath_nodes(".//article").size.should eq(1)
    list.content.should contain(topic.title)
    list.xpath_node(".//h2/span[@title='未读']").should_not be_nil
    URI.parse(topic_path).query_params["following"].should eq("true")
    URI.parse(topic_path).query_params["only_show_unread"].should eq("true")
    response = ApiClient.new.get("#{topic_path}&backdoor_user_id=#{reader.id}")
    document = XML.parse_html(response.body)
    canonical = URI.parse(document.xpath_node("//link[@rel='canonical']").not_nil!["href"])

    response.status_code.should eq(200)
    canonical.path.should eq("/forum/#{topic.id}")
    canonical.query.should be_nil

    document.xpath_nodes("//main//aside/nav//a").each do |link|
      params = URI.parse(link["href"]).query_params
      params["following"].should eq("true")
      params["only_show_unread"].should eq("true")
    end

    response = ApiClient.new.headers("HX-Request-Type": "partial").get(path)
    document = XML.parse_html(response.body)
    document.xpath_node("//main").should be_nil
    document.xpath_nodes("//article").should be_empty
    TopicFollowQuery.new.topic_id(topic.id).follower_id(reader.id).any?.should be_true
  end

  it "paginates unread topics and shows account-specific markers only to signed-in readers" do
    author = UserFactory.create
    reader = UserFactory.create
    node = topic_read_node
    topics = Array.new(21) do |index|
      topic_read_topic(author, node, "未读分页 #{index}")
    end
    response = ApiClient.new.get("/forum?only_show_unread=true&backdoor_user_id=#{reader.id}")
    document = XML.parse_html(response.body)
    list = document.xpath_node("//section[@id='forum-topics']").not_nil!
    next_path = list.xpath_node("./div/nav/a").not_nil!["href"]

    list.xpath_nodes(".//article").size.should eq(20)
    list.xpath_nodes(".//h2/span[@title='未读']").size.should eq(20)
    URI.parse(next_path).query_params["only_show_unread"].should eq("true")
    response = ApiClient.new.headers("HX-Request-Type": "partial").get(next_path)
    document = XML.parse_html(response.body)

    response.status_code.should eq(200)
    document.xpath_node("//main").should be_nil
    document.xpath_nodes("//article").size.should eq(1)
    document.content.should contain(topics.first.title)

    response = ApiClient.new.get("/forum?backdoor_user_id=#{reader.id}")
    XML.parse_html(response.body).xpath_nodes("//section[@id='forum-topics']//h2/span[@title='未读']").size.should eq(20)
    response = ApiClient.new.get("/forum")
    XML.parse_html(response.body).xpath_nodes("//section[@id='forum-topics']//h2/span[@title='未读']").should be_empty
  end
end
