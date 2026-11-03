require "../spec_helper"

describe "Notification targets" do
  it "creates target columns, indexes and counters directly, and rolls back cleanly" do
    AppDatabase.transaction do
      AppDatabase.exec "CREATE SCHEMA notification_targets_spec"
      AppDatabase.exec "SET LOCAL search_path TO notification_targets_spec"
      AppDatabase.exec "CREATE TABLE users (id bigint PRIMARY KEY, notifications_count integer NOT NULL DEFAULT 0, unread_notifications_count integer NOT NULL DEFAULT 0)"
      AppDatabase.exec "INSERT INTO users (id) VALUES (1), (2)"
      migration = CreateNotifications::V20261004120000.new
      migration.migrate
      migration.prepared_statements.each { |statement| AppDatabase.exec(statement) }
      columns = AppDatabase.query_all(
        "SELECT column_name FROM information_schema.columns WHERE table_schema = 'notification_targets_spec' AND table_name = 'notifications'",
        as: String
      )
      indexes = AppDatabase.query_all(
        "SELECT indexdef FROM pg_indexes WHERE schemaname = 'notification_targets_spec' AND tablename = 'notifications'",
        as: String
      )

      columns.should contain("topic_id")
      columns.should contain("comment_id")
      columns.should_not contain("url")
      indexes.any?(&.includes?("(user_id, topic_id, comment_id, kind)")).should be_true
      indexes.any? { |index| index.includes?("(user_id, comment_id, kind)") && index.includes?("WHERE (comment_id IS NOT NULL)") }.should be_true
      indexes.any? { |index| index.includes?("notifications_user_id_index") && index.includes?("WHERE (read_at IS NULL)") }.should be_true

      AppDatabase.exec <<-SQL
        INSERT INTO notifications (user_id, actor_id, kind, source_title, excerpt, topic_id, comment_id) VALUES
          (1, 2, 3, '主题通知', '摘要', 10, NULL),
          (1, 2, 3, '主题评论', '摘要', 10, 100),
          (1, 2, 3, '文档评论', '摘要', NULL, 200)
        SQL
      AppDatabase.query_one(
        "SELECT notifications_count, unread_notifications_count FROM users WHERE id = 1",
        as: {Int32, Int32}
      ).should eq({3, 3})
      AppDatabase.exec "UPDATE notifications SET read_at = now() WHERE comment_id = 100"
      AppDatabase.query_one(
        "SELECT notifications_count, unread_notifications_count FROM users WHERE id = 1",
        as: {Int32, Int32}
      ).should eq({3, 2})

      migration.reset_prepared_statements
      migration.rollback
      migration.prepared_statements.each { |statement| AppDatabase.exec(statement) }

      AppDatabase.query_one(
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'notification_targets_spec' AND table_name = 'notifications'",
        as: Int64
      ).should eq(0)
      AppDatabase.query_one(
        "SELECT COUNT(*) FROM pg_proc WHERE pronamespace = 'notification_targets_spec'::regnamespace",
        as: Int64
      ).should eq(0)

      AppDatabase.rollback
    end
  end

  it "stores topic and comment targets separately, deduplicates them, and retains physically deleted targets" do
    author = UserFactory.create
    recipient = UserFactory.create
    node = SaveNode.create!(name: "通知目标", slug: "notification-targets", summary: "测试", color: "#0284c7", position: 0)
    topic = CreateTopic.create!(
      user_id: author.id,
      node_id: node.id,
      title: "通知目标",
      content: "@#{recipient.login_name} 主题提及"
    )
    comment = CreateComment.create!(
      user_id: author.id,
      comment_thread_id: topic.comment_thread!.not_nil!.id,
      content: "@#{recipient.login_name} 评论提及"
    )
    doc = SaveDoc.create!(path_index: "/docs/notification-targets", content: "文档")
    doc_comment = CreateComment.create!(
      user_id: author.id,
      comment_thread_id: doc.comment_thread!.not_nil!.id,
      content: "@#{recipient.login_name} 文档评论提及"
    )
    topic_notification = NotificationQuery.new.user_id(recipient.id).for_target(topic).first
    comment_notification = NotificationQuery.new.user_id(recipient.id).for_target(comment).first
    doc_notification = NotificationQuery.new.user_id(recipient.id).for_target(doc_comment).first

    {topic_notification.topic_id, topic_notification.comment_id}.should eq({topic.id, nil})
    {comment_notification.topic_id, comment_notification.comment_id}.should eq({topic.id, comment.id})
    {doc_notification.topic_id, doc_notification.comment_id}.should eq({nil, doc_comment.id})
    topic_notification.url.should eq("/forum/#{topic.id}")
    comment_notification.url.should eq("/comments/#{comment.id}")
    doc_notification.url.should eq("/comments/#{doc_comment.id}")
    NotificationQuery.new.user_id(recipient.id).topic_id(topic.id).select_count.should eq(2)

    UpdateTopic.update!(topic, content: "@#{recipient.login_name} 再次提及")
    UpdateComment.update!(comment, content: "@#{recipient.login_name} 再次提及")
    NotificationQuery.new.user_id(recipient.id).select_count.should eq(3)
    TopicQuery.new.id(topic.id).delete
    CommentQuery.new.id(doc_comment.id).delete

    NotificationQuery.new.user_id(recipient.id).select_count.should eq(3)
    NotificationQuery.find(comment_notification.id).comment_id.should eq(comment.id)
    recipient.reload.unread_notifications_count.should eq(3)

    {topic_notification, comment_notification, doc_notification}.each do |notification|
      ApiClient.new.get(notification.url).status_code.should eq(404)
    end
  end

  it "rejects a notification without a target" do
    user = UserFactory.create

    SaveNotification.create(
      user_id: user.id,
      actor_id: user.id,
      kind: :mention,
      source_title: "缺少目标",
      excerpt: "摘要"
    ) do |operation, notification|
      notification.should be_nil
      operation.not_nil!.errors[:topic_id].should_not be_empty
    end
  end
end
