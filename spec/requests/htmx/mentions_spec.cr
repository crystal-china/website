require "../../spec_helper"

describe Htmx::Users::Autocomplete do
  around_each do |example|
    previous_emails = ENV["ADMIN_EMAILS"]?
    ENV["ADMIN_EMAILS"] = "autocomplete-admin@example.com"

    example.run
  ensure
    if previous_emails
      ENV["ADMIN_EMAILS"] = previous_emails
    else
      ENV.delete("ADMIN_EMAILS")
    end
  end

  it "renders the editor's candidates immediately after its textarea" do
    user = UserFactory.create
    response = ApiClient.new.get("/forum/new?backdoor_user_id=#{user.id}")
    document = XML.parse_html(response.body)
    textarea = document.xpath_node("//textarea[@data-users-autocomplete-url]").not_nil!
    list = textarea.parent.not_nil!.xpath_node(".//div[contains(@class, 'user-autocomplete-options')]").not_nil!

    response.status_code.should eq(200)
    textarea["data-users-autocomplete-url"].should eq(Htmx::Users::Autocomplete.path)
    list.name.should eq("div")
    list["hidden"]?.should_not be_nil
    list["class"].should contain("absolute")
    textarea.parent.not_nil!["class"].should contain("relative")
  end

  it "requires login and hides opted-out users from ordinary users" do
    user = UserFactory.create
    UserFactory.create &.login_name("MingHidden").mention_notifications_enabled(false)
    UserFactory.create &.login_name("MingPublic")

    ApiClient.new.headers("HX-Request-Type": "partial").get("/htmx/users/autocomplete?q=mi").status_code.should eq(401)
    response = ApiClient.new.get("/htmx/users/autocomplete?q=mi&backdoor_user_id=#{user.id}")

    response.status_code.should eq(200)
    JSON.parse(response.body).as_a.map(&.["login_name"].as_s).should eq(["MingPublic"])
  end

  it "matches login-name prefixes regardless of notification or online visibility preferences" do
    admin = UserFactory.create &.email("autocomplete-admin@example.com")
    UserFactory.create &.login_name("MingHidden").nickname("小明").mention_notifications_enabled(false).hide_online_status(true)
    UserFactory.create &.login_name("MingPublic").nickname("大明")
    UserFactory.create &.login_name("OtherUser").nickname("MingDisplay")
    response = ApiClient.new.get("/htmx/users/autocomplete?q=mINg&backdoor_user_id=#{admin.id}")
    users = JSON.parse(response.body).as_a

    response.status_code.should eq(200)
    response.headers["Cache-Control"].should eq("no-store")
    users.map(&.["login_name"].as_s).should eq(["MingHidden", "MingPublic"])
    users.first["nickname"].as_s.should eq("小明")
    users.each do |user|
      user.as_h.keys.sort!.should eq(["login_name", "nickname"])
    end

    response = ApiClient.new.get("/htmx/users/autocomplete?q=ing&backdoor_user_id=#{admin.id}")
    JSON.parse(response.body).as_a.should be_empty
  end

  it "requires two characters and treats LIKE wildcards as literal characters" do
    admin = UserFactory.create &.email("autocomplete-admin@example.com")
    UserFactory.create &.login_name("Mi_Sky")
    UserFactory.create &.login_name("MiSky")
    UserFactory.create &.login_name("_ming")

    {
      ""        => [] of String,
      "m"       => [] of String,
      "a" * 101 => [] of String,
      "mi_"     => ["Mi_Sky"],
      "mi%"     => [] of String,
      "mi\\"    => [] of String,
      "_m"      => ["_ming"],
    }.each do |prefix, expected|
      params = URI::Params.encode({"q" => prefix, "backdoor_user_id" => admin.id.to_s})
      response = ApiClient.new.get("/htmx/users/autocomplete?#{params}")

      response.status_code.should eq(200)
      JSON.parse(response.body).as_a.map(&.["login_name"].as_s).should eq(expected)
    end
  end

  it "returns at most eight accounts sorted by login name" do
    admin = UserFactory.create &.email("autocomplete-admin@example.com")
    10.times do |index|
      UserFactory.create &.login_name("Member#{9 - index}")
    end
    response = ApiClient.new.get("/htmx/users/autocomplete?q=member&backdoor_user_id=#{admin.id}")

    response.status_code.should eq(200)
    JSON.parse(response.body).as_a.map(&.["login_name"].as_s).should eq(Array.new(8) { |index| "Member#{index}" })
  end
end
