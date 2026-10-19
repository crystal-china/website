require "timecop"
require "../spec_helper"

describe OnlinePresence do
  it "accumulates actual intervals across refreshes and devices without changing profile timestamps or audits" do
    user = UserFactory.create
    presence = OnlinePresence.new
    at = Time.unix(Time.utc.to_unix)

    {0.seconds, 400.milliseconds, 800.milliseconds, 1200.milliseconds, 1.minute, 2.minutes, 2.minutes}.each_with_index do |offset, index|
      Timecop.freeze(at + offset) do
        presence.record(user, "127.0.0.#{index % 2 + 1}").should eq({1, 0})
      end
    end

    UserQuery.find(user.id).online_seconds.should eq(0)
    presence.flush
    presence.flush
    updated = UserQuery.find(user.id)

    updated.online_seconds.should eq(120)
    updated.last_active_at.should eq(at + 2.minutes)
    updated.updated_at.should eq(user.updated_at)
    UserAuditQuery.new.user_id(user.id).any?.should be_false
  end

  it "does not count a gap longer than three minutes" do
    user = UserFactory.create
    presence = OnlinePresence.new
    at = Time.unix(Time.utc.to_unix)

    {0.minutes, 2.minutes, 10.minutes, 12.minutes}.each do |offset|
      Timecop.freeze(at + offset) { presence.record(user, "127.0.0.1") }
    end
    presence.flush

    UserQuery.find(user.id).online_seconds.should eq(240)
  end

  it "persists pending time and last activity even after the online cache expires" do
    user = UserFactory.create
    presence = OnlinePresence.new
    at = Time.unix(Time.utc.to_unix)

    Timecop.freeze(at) { presence.record(user, "127.0.0.1") }
    Timecop.freeze(at + 2.minutes) { presence.record(user, "127.0.0.1") }
    Timecop.freeze(at + 6.minutes) do
      presence.record(nil, "127.0.0.2").should eq({0, 1})
      presence.flush
    end

    updated = UserQuery.find(user.id)
    updated.online_seconds.should eq(120)
    updated.last_active_at.should eq(at + 2.minutes)
  end

  it "increments existing totals without moving last activity backwards" do
    at = Time.unix(Time.utc.to_unix)
    user = UserFactory.create &.online_seconds(3600_i64).last_active_at(at + 1.hour)
    presence = OnlinePresence.new

    Timecop.freeze(at) { presence.record(user, "127.0.0.1") }
    Timecop.freeze(at + 1.minute) { presence.record(user, "127.0.0.1") }
    presence.flush
    updated = UserQuery.find(user.id)

    updated.online_seconds.should eq(3660)
    updated.last_active_at.should eq(user.last_active_at)
  end

  it "does not double count time when the clock moves backwards" do
    user = UserFactory.create
    presence = OnlinePresence.new
    at = Time.unix(Time.utc.to_unix)

    {0.minutes, 2.minutes, 1.minute, 3.minutes}.each do |offset|
      Timecop.freeze(at + offset) { presence.record(user, "127.0.0.1") }
    end
    presence.flush

    UserQuery.find(user.id).online_seconds.should eq(180)
  end

  it "retains pending time when a database write fails" do
    user = UserFactory.create
    presence = OnlinePresence.new
    at = Time.unix(Time.utc.to_unix)

    Timecop.freeze(at) { presence.record(user, "127.0.0.1") }
    Timecop.freeze(at + 2.minutes) { presence.record(user, "127.0.0.1") }
    AppDatabase.exec "ALTER TABLE users ADD CONSTRAINT online_time_spec_limit CHECK (online_seconds = 0)"

    expect_raises(PQ::PQError) { presence.flush }
    AppDatabase.exec "ALTER TABLE users DROP CONSTRAINT online_time_spec_limit"
    presence.flush

    UserQuery.find(user.id).online_seconds.should eq(120)
  ensure
    AppDatabase.exec "ALTER TABLE users DROP CONSTRAINT IF EXISTS online_time_spec_limit"
  end

  it "renders cumulative hours and minutes in both locales" do
    user = UserFactory.create &.online_seconds(9030_i64)

    {"zh-CN" => {"累计在线时长", "2 小时 30 分钟"}, "en" => {"Time online", "2h 30m"}}.each do |locale, labels|
      response = ApiClient.new.get("/users/#{user.login_name}/profile?locale=#{locale}")
      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      document.xpath_node("//dl/dt[last()]").not_nil!.content.should eq(labels[0])
      document.xpath_node("//dl/dd[last()]").not_nil!.content.should eq(labels[1])
    end
  end

  it "initializes new users with zero online seconds" do
    user = UserFactory.create

    UserQuery.find(user.id).online_seconds.should eq(0)
  end
end
