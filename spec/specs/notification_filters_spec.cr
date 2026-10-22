require "../spec_helper"

describe "Notification filters" do
  it "filters only the current user's unread notifications and preserves the filter across pages" do
    user = UserFactory.create
    actor = UserFactory.create
    notifications = Array.new(23) do |index|
      SaveNotification.create!(
        user_id: user.id,
        actor_id: actor.id,
        kind: :mention,
        url: "/docs/index",
        source_title: "通知#{index}",
        excerpt: "通知摘要",
        read_at: index < 21 ? nil : Time.utc
      )
    end
    SaveNotification.create!(
      user_id: actor.id,
      actor_id: user.id,
      kind: :mention,
      url: "/docs/index",
      source_title: "其他用户的通知",
      excerpt: "不可见"
    )
    client = ApiClient.new
    response = client.get("/notifications?unread=true&backdoor_user_id=#{user.id}")
    document = XML.parse_html(response.body)

    response.status_code.should eq(200)
    response.body.should_not contain("其他用户的通知")
    response.body.should contain("21 条未读通知")
    document.xpath_nodes("//section//form").map(&.["action"]).should eq(
      notifications.first(21).reverse.first(20).map { |notification| "/notifications/#{notification.id}/read" }
    )
    filter = document.xpath_node("//a[contains(@class, 'segmented-option-active')]").not_nil!
    filter.content.should eq("仅未读")
    filter["href"].should eq("/notifications?unread=true")
    filter["hx-target"].should eq("#notifications-content")
    filter["hx-swap"].should eq("innerHTML")
    filter["hx-push-url"].should eq("false")
    document.xpath_node("//button[@id='notifications-read-all']").not_nil!["hx-post"].should eq("/notifications/read_all?unread=true")

    next_page = document.xpath_node("//nav/a").not_nil!["href"]
    URI.parse(next_page).query_params["unread"].should eq("true")
    response = client.get("#{next_page}&backdoor_user_id=#{user.id}")
    document = XML.parse_html(response.body)
    document.xpath_nodes("//section//form").map(&.["action"]).should eq(["/notifications/#{notifications.first.id}/read"])
    response.body.should contain("第 2 / 2 页")
    document.xpath_nodes("//nav/a").each do |link|
      URI.parse(link["href"]).query_params["unread"].should eq("true")
    end

    response = client.get("/notifications?unread=false&backdoor_user_id=#{user.id}")
    document = XML.parse_html(response.body)
    document.xpath_nodes("//section//form").map(&.["action"]).should eq(
      notifications.reverse.first(20).map { |notification| "/notifications/#{notification.id}/read" }
    )
    document.xpath_node("//a[contains(@class, 'segmented-option-active')]").not_nil!["href"].should eq("/notifications")
    NotificationQuery.new.user_id(user.id).read_at.is_nil.select_count.should eq(21)
    ApiClient.new.headers("HX-Request-Type": "partial").get("/notifications?unread=true").status_code.should eq(401)
  end

  it "keeps the unread filter after marking all read and allows returning to all notifications" do
    user = UserFactory.create
    actor = UserFactory.create
    notification = SaveNotification.create!(
      user_id: user.id,
      actor_id: actor.id,
      kind: :mention,
      url: "/docs/index",
      source_title: "自己的通知",
      excerpt: "通知摘要"
    )
    foreign = SaveNotification.create!(
      user_id: actor.id,
      actor_id: user.id,
      kind: :mention,
      url: "/docs/index",
      source_title: "其他用户的通知",
      excerpt: "不可见"
    )

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      response = ApiClient.new.post("/notifications/read_all?unread=true&backdoor_user_id=#{user.id}")
      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      response.headers["Location"]?.should be_nil
      response.body.should contain("没有未读通知。")
      document.xpath_nodes("//section//form").should be_empty
      document.xpath_nodes("//nav").should be_empty
      document.xpath_node("//a[contains(@class, 'segmented-option-active')]").not_nil!["href"].should eq("/notifications?unread=true")
      document.xpath_node("//hx-partial[@hx-target='#notifications-controls']/div/button[@disabled]").should_not be_nil
      document.xpath_node("//*[@id='notification-status']//span[@aria-hidden='true']").should be_nil
      NotificationQuery.find(notification.id).read_at.should_not be_nil
      NotificationQuery.find(foreign.id).read_at.should be_nil

      all_link = document.xpath_node("//a[@href='/notifications']").not_nil!
      response = ApiClient.new.get("#{all_link["href"]}?backdoor_user_id=#{user.id}")
      response.body.should contain("自己的通知")
      response.body.should_not contain("其他用户的通知")
    end

    response = ApiClient.new.get("/notifications?unread=true&locale=en&backdoor_user_id=#{user.id}")
    response.body.should contain("No unread notifications.")
  end
end
