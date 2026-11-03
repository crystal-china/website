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
        comment_id: 1_i64,
        source_title: "通知#{index}",
        excerpt: "通知摘要",
        read_at: index < 21 ? nil : Time.utc
      )
    end
    SaveNotification.create!(
      user_id: actor.id,
      actor_id: user.id,
      kind: :mention,
      comment_id: 1_i64,
      source_title: "其他用户的通知",
      excerpt: "不可见"
    )
    client = ApiClient.new
    response = client.get("/notifications?only_show_unread=true&backdoor_user_id=#{user.id}")
    document = XML.parse_html(response.body)

    response.status_code.should eq(200)
    response.body.should_not contain("其他用户的通知")
    response.body.should contain("21 条未读通知")
    document.xpath_nodes("//section//form").map(&.["action"]).should eq(
      notifications.first(21).reverse.first(20).map { |notification| "/notifications/#{notification.id}/read" }
    )
    filter = document.xpath_node("//a[contains(@class, 'segmented-option-active')]").not_nil!
    filter.content.should eq("仅未读")
    filter["href"].should eq("/notifications?only_show_unread=true")
    controls = document.xpath_node("//div[@id='notifications-controls']").not_nil!
    controls["hx-target:inherited"].should eq("#notifications-content")
    controls["hx-swap:inherited"].should eq("innerHTML")
    controls["hx-push-url:inherited"].should eq("false")
    filter["hx-get"]?.should be_nil
    document.xpath_node("//button[@id='notifications-read-all']").not_nil!["hx-post"].should eq("/notifications/read_all")

    next_page = document.xpath_node("//nav/a").not_nil!["href"]
    URI.parse(next_page).query_params["only_show_unread"].should eq("true")
    response = client.get("#{next_page}&backdoor_user_id=#{user.id}")
    document = XML.parse_html(response.body)
    document.xpath_nodes("//section//form").map(&.["action"]).should eq(["/notifications/#{notifications.first.id}/read"])
    response.body.should contain("第 2 / 2 页")
    document.xpath_nodes("//nav/a").each do |link|
      URI.parse(link["href"]).query_params["only_show_unread"].should eq("true")
    end

    response = client.get("/notifications?only_show_unread=false&backdoor_user_id=#{user.id}")
    document = XML.parse_html(response.body)
    document.xpath_nodes("//section//form").map(&.["action"]).should eq(
      notifications.reverse.first(20).map { |notification| "/notifications/#{notification.id}/read" }
    )
    document.xpath_node("//a[contains(@class, 'segmented-option-active')]").not_nil!["href"].should eq("/notifications?only_show_unread=false")
    NotificationQuery.new.user_id(user.id).read_at.is_nil.select_count.should eq(21)
    ApiClient.new.headers("HX-Request-Type": "partial").get("/notifications?only_show_unread=true").status_code.should eq(401)
  end

  it "keeps the unread filter after marking all read and allows returning to all notifications" do
    user = UserFactory.create
    actor = UserFactory.create
    notification = SaveNotification.create!(
      user_id: user.id,
      actor_id: actor.id,
      kind: :mention,
      comment_id: 1_i64,
      source_title: "自己的通知",
      excerpt: "通知摘要"
    )
    foreign = SaveNotification.create!(
      user_id: actor.id,
      actor_id: user.id,
      kind: :mention,
      comment_id: 1_i64,
      source_title: "其他用户的通知",
      excerpt: "不可见"
    )

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      client = ApiClient.new
      response = client.get("/notifications?only_show_unread=true&backdoor_user_id=#{user.id}")
      headers = HTTP::Headers.new
      HTTP::Cookies.from_server_headers(response.headers).add_request_headers(headers)
      client.headers(Cookie: headers["Cookie"])

      response = client.post("/notifications/read_all?backdoor_user_id=#{user.id}")
      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      response.headers["Location"]?.should be_nil
      response.body.should contain("没有未读通知。")
      document.xpath_nodes("//section//form").should be_empty
      document.xpath_nodes("//nav").should be_empty
      document.xpath_node("//a[contains(@class, 'segmented-option-active')]").not_nil!["href"].should eq("/notifications?only_show_unread=true")
      document.xpath_node("//hx-partial[@hx-target='#notifications-controls']/div/button[@disabled]").should_not be_nil
      document.xpath_node("//*[@id='notification-status']//span[@aria-hidden='true']").should be_nil
      NotificationQuery.find(notification.id).read_at.should_not be_nil
      NotificationQuery.find(foreign.id).read_at.should be_nil

      all_link = document.xpath_node("//a[@href='/notifications?only_show_unread=false']").not_nil!
      response = ApiClient.new.get("#{all_link["href"]}&backdoor_user_id=#{user.id}")
      response.body.should contain("自己的通知")
      response.body.should_not contain("其他用户的通知")
    end

    response = ApiClient.new.get("/notifications?only_show_unread=true&locale=en&backdoor_user_id=#{user.id}")
    response.body.should contain("No unread notifications.")
  end

  it "remembers the filter across reopening, page loads, heartbeats, and marking all read" do
    user = UserFactory.create
    actor = UserFactory.create
    SaveNotification.create!(
      user_id: user.id,
      actor_id: actor.id,
      kind: :mention,
      comment_id: 1_i64,
      source_title: "未读通知",
      excerpt: "通知摘要"
    )
    client = ApiClient.new
    response = client.get("/?backdoor_user_id=#{user.id}")
    document = XML.parse_html(response.body)

    document.xpath_node("//*[@id='notifications-controls']//a[contains(@class, 'segmented-option-active')]").not_nil!.content.should eq("全部")

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      {
        {"GET", "/notifications?only_show_unread=true", "仅未读"},
        {"GET", "/", "仅未读"},
        {"PATCH", "/htmx/online_users", nil},
        {"GET", "/notifications", "仅未读"},
        {"POST", "/notifications/read_all", "仅未读"},
        {"GET", "/notifications", "仅未读"},
        {"GET", "/notifications?only_show_unread=false", "全部"},
        {"GET", "/", "全部"},
        {"GET", "/notifications", "全部"},
      }.each do |method, path, selected|
        headers = HTTP::Headers.new
        HTTP::Cookies.from_server_headers(response.headers).add_request_headers(headers)
        client.headers(Cookie: headers["Cookie"])

        separator = path.includes?('?') ? '&' : '?'
        path = "#{path}#{separator}backdoor_user_id=#{user.id}"
        response = case method
                   when "PATCH" then client.patch(path)
                   when "POST"  then client.post(path)
                   else              client.get(path)
                   end
        document = XML.parse_html(response.body)

        response.status_code.should eq(200)
        if selected
          document.xpath_node("//*[@id='notifications-controls']//a[contains(@class, 'segmented-option-active')]").not_nil!.content.should eq(selected)
        else
          document.xpath_node("//*[@id='notifications-controls']").should be_nil
        end
      end

      response.body.should contain("未读通知")
      NotificationQuery.new.user_id(user.id).read_at.is_nil.any?.should be_false
    end
  end
end
