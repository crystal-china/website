require "../spec_helper"
require "../../tasks/db/fix/notification_counts"

private def counter_notification(user : User, actor : User, *, read_at : Time? = nil) : Notification
  SaveNotification.create!(
    user_id: user.id,
    actor_id: actor.id,
    kind: :mention,
    url: "/docs/index",
    source_title: "通知计数测试",
    excerpt: "测试摘要",
    read_at: read_at
  )
end

private def expect_notification_counts(user : User, total : Int32, unread : Int32) : Nil
  current = user.reload

  {current.notifications_count, current.unread_notifications_count}.should eq({total, unread})
  current.updated_at.should eq(user.updated_at)
end

describe "Notification counters" do
  it "tracks inserts, read transitions and deletes independently for each recipient without changing user timestamps" do
    user = UserFactory.create
    other = UserFactory.create
    actor = UserFactory.create

    expect_notification_counts(user, 0, 0)
    unread = counter_notification(user, actor)
    read = counter_notification(user, actor, read_at: Time.utc)
    other_unread = counter_notification(other, actor)
    expect_notification_counts(user, 2, 1)
    expect_notification_counts(other, 1, 1)
    SaveNotification.update!(unread, source_title: "修改标题不影响计数", read_at: Time.utc)
    expect_notification_counts(user, 2, 0)
    NotificationQuery.new.id(unread.id).update(read_at: Time.utc)
    expect_notification_counts(user, 2, 0)
    NotificationQuery.new.id(unread.id).update(read_at: nil)
    expect_notification_counts(user, 2, 1)

    NotificationQuery.new.id(read.id).delete
    NotificationQuery.new.id(unread.id).delete
    expect_notification_counts(user, 0, 0)
    expect_notification_counts(other, 1, 1)
    NotificationQuery.new.id(other_unread.id).delete
    expect_notification_counts(other, 0, 0)
    UserAuditQuery.new.select_count.should eq(0)
  end

  it "rolls back counters with notifications and handles account cascade deletion" do
    user = UserFactory.create
    actor = UserFactory.create

    expect_raises(Exception, "rollback counters") do
      AppDatabase.transaction do
        counter_notification(user, actor)
        expect_notification_counts(user, 1, 1)

        raise "rollback counters"
      end
    end

    expect_notification_counts(user, 0, 0)
    NotificationQuery.new.user_id(user.id).any?.should be_false
    counter_notification(user, actor)
    counter_notification(user, actor, read_at: Time.utc)
    UserQuery.new.id(actor.id).delete
    expect_notification_counts(user, 0, 0)

    # 删除收件人时，其通知也被级联删除；无须再更新已不存在的用户。
    counter_notification(user, user)
    UserQuery.new.id(user.id).delete
    NotificationQuery.new.user_id(user.id).any?.should be_false
  end

  it "backfills existing notifications and repairs all users without changing read state or audit history" do
    user = UserFactory.create
    empty_user = UserFactory.create
    actor = UserFactory.create
    unread = counter_notification(user, actor)
    read = counter_notification(user, actor, read_at: Time.utc)
    migration = AddNotificationCountersToUsers::V20261025130000.new

    migration.down(quiet: true)
    migration.up(quiet: true)

    expect_notification_counts(user, 2, 1)
    expect_notification_counts(empty_user, 0, 0)
    AppDatabase.exec("UPDATE users SET notifications_count = 99, unread_notifications_count = 99")
    Db::Fix::NotificationCounts.new.call
    Db::Fix::NotificationCounts.new.call
    expect_notification_counts(user, 2, 1)
    expect_notification_counts(empty_user, 0, 0)
    expect_notification_counts(actor, 0, 0)
    NotificationQuery.find(unread.id).updated_at.should eq(unread.updated_at)
    NotificationQuery.find(unread.id).read_at.should be_nil
    NotificationQuery.find(read.id).read_at.should eq(read.read_at)
    UserAuditQuery.new.select_count.should eq(0)
  ensure
    migration.try(&.up(quiet: true)) if migration.try(&.pending?)
  end

  it "paginates all and unread notifications and renders the bell without COUNT or unread existence queries" do
    user = UserFactory.create
    actor = UserFactory.create

    45.times do |index|
      counter_notification(user, actor, read_at: index < 23 ? nil : Time.utc)
    end

    test_mode = Pulsar.test_mode_enabled?
    Pulsar.test_mode_enabled = true
    client = ApiClient.new

    {"page=3" => 5, "only_show_unread=true&page=2" => 3}.each do |params, expected_size|
      Avram::Events::QueryEvent.logged_events.clear
      response = client.get("/notifications?#{params}&backdoor_user_id=#{user.id}")
      queries = Avram::Events::QueryEvent.logged_events.map(&.query)
      headers = HTTP::Headers.new
      HTTP::Cookies.from_server_headers(response.headers).add_request_headers(headers)
      client.headers(Cookie: headers["Cookie"])

      response.status_code.should eq(200)
      XML.parse_html(response.body).xpath_nodes("//section//form").size.should eq(expected_size)
      XML.parse_html(response.body).xpath_node("//*[@id='notification-status']//span[@aria-hidden='true']").not_nil!.content.should eq("23")
      queries.any?(&.matches?(/\bCOUNT\s*\(/i)).should be_false
      queries.any?(&.matches?(/SELECT\s+1\b.*notifications/i)).should be_false
    end

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      Avram::Events::QueryEvent.logged_events.clear
      response = client.post("/notifications/read_all?backdoor_user_id=#{user.id}")
      queries = Avram::Events::QueryEvent.logged_events.map(&.query)
      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      document.xpath_nodes("//section//form").should be_empty
      document.xpath_node("//button[@id='notifications-read-all'][@disabled]").should_not be_nil
      document.xpath_node("//*[@id='notification-status']//span[@aria-hidden='true']").should be_nil
      expect_notification_counts(user, 45, 0)
      queries.any?(&.matches?(/\bCOUNT\s*\(/i)).should be_false
    end
  ensure
    Pulsar.test_mode_enabled = test_mode if test_mode.is_a?(Bool)
    Avram::Events::QueryEvent.logged_events.clear
  end

  it "refreshes the bell after an HTMX topic save creates a self mention" do
    user = UserFactory.create
    node = SaveNode.create!(name: "通知计数", slug: "notification-counts", summary: "测试", color: "#16a34a", position: 0)
    client = ApiClient.new.headers("HX-Request-Type": "full")

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      response = client.post(
        "/forum?backdoor_user_id=#{user.id}",
        topic: {title: "保存后的铃铛计数", node_id: node.id.to_s},
        content: "@#{user.login_name} 提及自己"
      )

      response.status_code.should eq(200)
      response.body.should contain("1 条未读通知")
      expect_notification_counts(user, 1, 1)
      topic = TopicQuery.new.user_id(user.id).first
      NotificationQuery.new.user_id(user.id).delete
      expect_notification_counts(user, 0, 0)

      response = client.put(
        "/forum/#{topic.id}?backdoor_user_id=#{user.id}",
        topic: {title: "再次保存后的铃铛计数"},
        content: "@#{user.login_name} 编辑后再次提及自己"
      )

      response.status_code.should eq(200)
      response.body.should contain("1 条未读通知")
      expect_notification_counts(user, 1, 1)
    end
  end
end
