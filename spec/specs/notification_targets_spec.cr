require "../spec_helper"

describe "Notification targets" do
  it "migrates existing targets and indexes without changing history, and restores URLs on rollback" do
    AppDatabase.transaction do
      AppDatabase.exec "CREATE SCHEMA notification_targets_spec"
      AppDatabase.exec "SET LOCAL search_path TO notification_targets_spec"
      AppDatabase.exec "CREATE TABLE comment_threads (id bigint PRIMARY KEY, topic_id bigint)"
      AppDatabase.exec "CREATE TABLE comments (id bigint PRIMARY KEY, comment_thread_id bigint, soft_deleted_at timestamptz)"
      AppDatabase.exec <<-SQL
        CREATE TABLE notifications (
          id bigint PRIMARY KEY, user_id bigint, kind integer, url text NOT NULL,
          read_at timestamptz, created_at timestamptz DEFAULT now(), updated_at timestamptz DEFAULT now()
        )
        SQL
      AppDatabase.exec "CREATE INDEX notifications_user_id_url_kind_index ON notifications (user_id, url, kind)"
      AppDatabase.exec "INSERT INTO comment_threads VALUES (1, 10), (2, NULL)"
      AppDatabase.exec "INSERT INTO comments VALUES (100, 1, now()), (200, 2, NULL)"
      AppDatabase.exec <<-SQL
        INSERT INTO notifications (id, user_id, kind, url, read_at) VALUES
          (1, 1, 3, '/forum/10', NULL),
          (2, 1, 3, '/comments/100', now()),
          (3, 1, 3, '/comments/200', NULL),
          (4, 1, 8, '/comments/999', NULL)
        SQL
      history = AppDatabase.query_all(
        "SELECT read_at, created_at, updated_at FROM notifications ORDER BY id",
        as: {Time?, Time, Time}
      )
      migration = ReplaceNotificationUrlsWithTargets::V20261103130000.new
      migration.migrate
      migration.prepared_statements.each { |statement| AppDatabase.exec(statement) }
      targets = AppDatabase.query_all(
        "SELECT topic_id, comment_id FROM notifications ORDER BY id",
        as: {Int64?, Int64?}
      )

      targets.should eq([{10_i64, nil}, {10_i64, 100_i64}, {nil, 200_i64}, {nil, 999_i64}])
      AppDatabase.query_all(
        "SELECT read_at, created_at, updated_at FROM notifications ORDER BY id",
        as: {Time?, Time, Time}
      ).should eq(history)

      indexes = AppDatabase.query_all(
        "SELECT indexdef FROM pg_indexes WHERE schemaname = 'notification_targets_spec' AND tablename = 'notifications'",
        as: String
      )

      indexes.any?(&.includes?("(user_id, topic_id, comment_id, kind)")).should be_true
      indexes.any? { |index| index.includes?("(user_id, comment_id, kind)") && index.includes?("WHERE (comment_id IS NOT NULL)") }.should be_true
      indexes.any?(&.includes?("url")).should be_false
      migration.reset_prepared_statements
      migration.rollback
      migration.prepared_statements.each { |statement| AppDatabase.exec(statement) }

      AppDatabase.query_all("SELECT url FROM notifications ORDER BY id", as: String).should eq([
        "/forum/10", "/comments/100", "/comments/200", "/comments/999",
      ])
      AppDatabase.query_one(
        "SELECT is_nullable FROM information_schema.columns WHERE table_schema = 'notification_targets_spec' AND table_name = 'notifications' AND column_name = 'url'",
        as: String
      ).should eq("NO")

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
