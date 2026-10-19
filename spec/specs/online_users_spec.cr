require "timecop"
require "../spec_helper"

describe "Online users" do
  before_each do
    ONLINE_PRESENCE.user_ids.each { |id| ONLINE_PRESENCE.hide(id) }
  end

  it "keeps hidden users out of public counts and lists while recording their time online" do
    user = UserFactory.create &.hide_online_status(true)
    presence = OnlinePresence.new
    at = Time.unix(Time.utc.to_unix)

    Timecop.freeze(at) { presence.record(user, "127.0.0.1").should eq({0, 0}) }
    Timecop.freeze(at + 2.minutes) do
      presence.record(user, "127.0.0.1").should eq({0, 0})
      presence.user_ids.should be_empty
      presence.flush
    end

    updated = UserQuery.find(user.id)
    updated.online_seconds.should eq(120)
    updated.last_active_at.should eq(at + 2.minutes)
    updated.updated_at.should eq(user.updated_at)
    UserAuditQuery.new.user_id(user.id).any?.should be_false
  end

  it "lists each visible user once and removes expired users" do
    user = UserFactory.create
    presence = OnlinePresence.new
    at = Time.unix(Time.utc.to_unix)

    Timecop.freeze(at) do
      presence.record(user, "127.0.0.1")
      presence.record(user, "127.0.0.2").should eq({1, 0})
      presence.user_ids.should eq([user.id])
      presence.record(nil, "127.0.0.3").should eq({1, 1})
    end

    Timecop.freeze(at + 3.minutes) do
      presence.user_ids.should be_empty
      presence.record(nil, "127.0.0.3").should eq({0, 1})
    end
  end

  it "requires sign-in and only lists visible online users with profile links" do
    viewer = UserFactory.create
    visible = UserFactory.create &.nickname("Visible member")
    hidden = UserFactory.create &.nickname("Hidden member")
    offline = UserFactory.create &.nickname("Offline member")
    ONLINE_PRESENCE.record(visible, "127.0.0.1")
    ONLINE_PRESENCE.record(hidden, "127.0.0.2")
    # Even an older presence entry must not override the persisted privacy setting.
    UserQuery.new.id(hidden.id).update(hide_online_status: true)

    response = ApiClient.new
      .headers("HX-Request-Type": "partial")
      .get("/online_users")
    response.status_code.should eq(401)

    response = ApiClient.new.get("/online_users?backdoor_user_id=#{viewer.id}")
    document = XML.parse_html(response.body)

    response.status_code.should eq(200)
    response.headers["Cache-Control"].should eq("no-store")
    document.xpath_node("//a[@href='#{Users::Show.with(login_name: visible.login_name).path}']").should_not be_nil
    response.body.should contain(visible.nickname)
    response.body.should contain("@#{visible.login_name}")
    response.body.should_not contain(hidden.nickname)
    response.body.should_not contain(offline.nickname)
  end

  it "shows a translated empty state" do
    user = UserFactory.create

    {"zh-CN" => "暂无公开在线的用户。", "en" => "No users are publicly online."}.each do |locale, label|
      response = ApiClient.new.get("/online_users?locale=#{locale}&backdoor_user_id=#{user.id}")

      response.status_code.should eq(200)
      response.body.should contain(label)
    end
  end

  it "translates user and guest counts without requiring sign-in" do
    {
      "zh-CN" => {"在线用户 1 人", "游客 0 人"},
      "en"    => {"1 user online", "0 guests"},
    }.each do |locale, labels|
      Rosetta.with_locale(locale) do
        html = Shared::OnlineUsers.new(
          user_count: 1,
          guest_count: 0,
          current_user: nil
        ).context(time_zone_context).render_to_string

        html.should contain(labels[0])
        html.should contain(labels[1])
        html.should_not contain("<button")
      end
    end
  end

  it "opens the dialog from the footer and keeps it outside the heartbeat swap target" do
    user = UserFactory.create
    client = ApiClient.new
    response = client.get("/?backdoor_user_id=#{user.id}")
    document = XML.parse_html(response.body)

    document.xpath_node("//footer//dialog[@id='online-users-dialog']").should_not be_nil
    document.xpath_node("//*[@id='online-users-status']//dialog").should be_nil
    document.xpath_node("//dialog[@id='online-users-dialog']").not_nil!["script"].should contain("on click")

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      response = client.patch("/htmx/online_users?backdoor_user_id=#{user.id}")
      response.status_code.should eq(200)
      document = XML.parse_html(response.body)
      button = document.xpath_node("//button[@hx-get='/online_users']").not_nil!

      button["hx-target"].should eq("#online-users-content")
      button["aria-controls"].should eq("online-users-dialog")
      response.body.should contain(%(hx-target="#notification-status"))

      response = ApiClient.new.patch("/htmx/online_users")
      response.body.should_not contain(%(hx-get="/online_users"))
      response.body.should_not contain(%(hx-target="#notification-status"))
    end
  end

  it "saves the preference, hides immediately, and only reappears after turning it off" do
    user = UserFactory.create
    other = UserFactory.create
    user.hide_online_status?.should be_false
    ONLINE_PRESENCE.record(user, "127.0.0.1")

    response = ApiClient.new.get("/users/#{user.id}/edit?backdoor_user_id=#{user.id}")
    response.body.should contain(%(name="user:hide_online_status"))
    response.body.should contain("始终隐身")

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      client = ApiClient.new
      response = client.put(
        "/users/#{user.id}?backdoor_user_id=#{user.id}",
        user: {hide_online_status: "true"}
      )

      response.status_code.should eq(303)
      updated = UserQuery.find(user.id)
      updated.hide_online_status?.should be_true
      UserQuery.find(other.id).hide_online_status?.should be_false
      ONLINE_PRESENCE.user_ids.should_not contain(user.id)
      client.patch("/htmx/online_users?backdoor_user_id=#{user.id}")
      ONLINE_PRESENCE.user_ids.should_not contain(user.id)

      response = client.get("/users/#{user.id}/edit?backdoor_user_id=#{user.id}")
      checkbox = XML.parse_html(response.body)
        .xpath_node("//input[@type='checkbox'][@name='user:hide_online_status']").not_nil!
      checkbox["checked"]?.should_not be_nil

      response = client.put("/users/#{user.id}?backdoor_user_id=#{user.id}", user: {hide_online_status: "false"})
      response.status_code.should eq(303)
      UserQuery.find(user.id).hide_online_status?.should be_false
      client.patch("/htmx/online_users?backdoor_user_id=#{user.id}")
      ONLINE_PRESENCE.user_ids.should contain(user.id)
    end

    UserAuditQuery.new.user_id(user.id).any?.should be_false
  end

  it "does not change public visibility when saving the preference fails" do
    user = UserFactory.create
    ONLINE_PRESENCE.record(user, "127.0.0.1")

    UpdateUser.update(
      user,
      hide_online_status: true,
      password: "short"
    ) do |op, _|
      op.saved?.should be_false
    end

    UserQuery.find(user.id).hide_online_status?.should be_false
    ONLINE_PRESENCE.user_ids.should contain(user.id)
  end

  it "hides activity from everyone, including the owner, until disabled" do
    user = UserFactory.create &.hide_online_status(true).last_active_at(Time.utc - 1.hour).online_seconds(3600_i64)
    other = UserFactory.create

    {nil, other, user}.each do |viewer|
      path = Users::Show.with(login_name: user.login_name).path
      path += "?backdoor_user_id=#{viewer.id}" if viewer
      response = ApiClient.new.get(path)
      card = Forum::AuthorCard.new(user: user, current_user: viewer).context(time_zone_context).render_to_string

      response.body.should_not contain("最后活跃于")
      response.body.should_not contain("累计在线时长")
      card.should_not contain("最后活跃于")
    end

    user = UpdateUser.update!(user, hide_online_status: false)
    response = ApiClient.new.get(Users::Show.with(login_name: user.login_name).path)
    card = Forum::AuthorCard.new(user: user, current_user: nil).context(time_zone_context).render_to_string

    response.body.should contain("最后活跃于")
    response.body.should contain("累计在线时长")
    card.should contain("最后活跃于")
  end

  it "defaults new users to visible" do
    user = UserFactory.create

    UserQuery.find(user.id).hide_online_status?.should be_false
  end
end
