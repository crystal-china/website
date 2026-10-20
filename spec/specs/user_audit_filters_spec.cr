require "../spec_helper"

describe "Account history filters" do
  around_each do |example|
    previous_emails = ENV["ADMIN_EMAILS"]?
    ENV["ADMIN_EMAILS"] = "audit-filter-admin@example.com"

    example.run
  ensure
    if previous_emails
      ENV["ADMIN_EMAILS"] = previous_emails
    else
      ENV.delete("ADMIN_EMAILS")
    end
  end

  it "renders a GET search form and all event types in both languages" do
    admin = UserFactory.create &.email("audit-filter-admin@example.com")

    {"zh-CN" => "所有事件", "en" => "All events"}.each do |locale, all_events|
      response = ApiClient.new.get("/user_audits?locale=#{locale}&backdoor_user_id=#{admin.id}")
      document = XML.parse_html(response.body)
      form = document.xpath_node("//main//form[@method='get']").not_nil!
      input = form.xpath_node(".//input[@type='search'][@name='login_name']").not_nil!

      response.status_code.should eq(200)
      form["action"].should eq("/user_audits")
      input["value"].should eq("")
      input["data-users-autocomplete-url"].should eq(Htmx::Users::Autocomplete.path)
      input.parent.not_nil!.xpath_node(".//div[@hidden][contains(@class, 'user-autocomplete-options')]").should_not be_nil
      form.xpath_node(".//select[@name='kind']/option[@value='']").not_nil!.content.should eq(all_events)
      form.xpath_nodes(".//select[@name='kind']/option").size.should eq(UserAudit::Kind.values.size + 1)
      form.xpath_node(".//input[@name='page']").should be_nil
      UserAudit::Kind.each do |kind|
        form.xpath_node(".//select/option[@value='#{kind.to_s.underscore}']").should_not be_nil
      end
    end
  end

  it "matches the account's complete login name case-insensitively, not its nickname or actor" do
    admin = UserFactory.create &.email("audit-filter-admin@example.com")
    user = UserFactory.create &.login_name("TargetUser").nickname("DisplayName")
    other = UserFactory.create &.login_name("OtherUser")
    SaveUserAudit.create!(user_id: user.id, actor_id: admin.id, kind: :oauth_signed_in, oauth_provider: "target-provider")
    SaveUserAudit.create!(user_id: other.id, actor_id: admin.id, kind: :oauth_signed_in, oauth_provider: "other-provider")

    response = ApiClient.new.get("/user_audits?login_name=%20tArGeTuSeR%20&backdoor_user_id=#{admin.id}")
    document = XML.parse_html(response.body)
    rows = document.xpath_nodes("//main//ol/li")

    response.status_code.should eq(200)
    rows.size.should eq(1)
    rows.first.content.should contain("target-provider")
    rows.first.content.should_not contain("other-provider")
    document.xpath_node("//input[@name='login_name']").not_nil!["value"].should eq("tArGeTuSeR")

    {"Target", "DisplayName", admin.login_name, "missing-user", "TargetUser%27"}.each do |login_name|
      response = ApiClient.new.get("/user_audits?login_name=#{login_name}&backdoor_user_id=#{admin.id}")

      response.status_code.should eq(200)
      XML.parse_html(response.body).xpath_node("//main//ol").should be_nil
    end
  end

  it "filters every event type and keeps the selected option" do
    admin = UserFactory.create &.email("audit-filter-admin@example.com")
    labels = {
      UserAudit::Kind::ProfileChanged   => "修改昵称",
      UserAudit::Kind::PasswordChanged  => "修改密码",
      UserAudit::Kind::OauthSignedIn    => "第三方登录",
      UserAudit::Kind::PasswordRemoved  => "移除本站密码",
      UserAudit::Kind::PasswordSignedIn => "密码登录",
    }
    UserAudit::Kind.each do |kind|
      SaveUserAudit.create!(
        user_id: admin.id,
        kind: kind,
        changed_column_name: kind.profile_changed? ? "nickname" : nil,
        from: kind.profile_changed? ? "旧昵称" : nil,
        to: kind.profile_changed? ? "新昵称" : nil,
        oauth_provider: kind.oauth_signed_in? ? "github" : nil
      )
    end

    labels.each do |kind, label|
      value = kind.to_s.underscore
      response = ApiClient.new.get("/user_audits?kind=#{value}&backdoor_user_id=#{admin.id}")
      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      document.xpath_nodes("//main//ol/li").size.should eq(1)
      document.xpath_node("//main//ol/li/h2").not_nil!.content.should eq(label)
      document.xpath_node("//select[@name='kind']/option[@selected]").not_nil!["value"].should eq(value)
    end

    response = ApiClient.new.get("/user_audits?kind=&backdoor_user_id=#{admin.id}")
    XML.parse_html(response.body).xpath_nodes("//main//ol/li").size.should eq(5)
    ApiClient.new.get("/user_audits?kind=unknown&backdoor_user_id=#{admin.id}").status_code.should eq(400)
  end

  it "combines both filters and retains them on pagination without adding page to the form" do
    admin = UserFactory.create &.email("audit-filter-admin@example.com")
    user = UserFactory.create &.login_name("TargetUser")
    21.times do
      SaveUserAudit.create!(user_id: user.id, kind: :password_signed_in)
    end
    SaveUserAudit.create!(user_id: user.id, kind: :oauth_signed_in, oauth_provider: "excluded-provider")
    SaveUserAudit.create!(user_id: admin.id, kind: :password_signed_in)
    response = ApiClient.new.get("/user_audits?login_name=targetuser&kind=password_signed_in&backdoor_user_id=#{admin.id}")
    document = XML.parse_html(response.body)
    next_path = document.xpath_node("//nav[@aria-label='账户记录分页']//a[.='下一页']").not_nil!["href"]
    query_params = URI.parse(next_path).query_params

    response.status_code.should eq(200)
    document.xpath_nodes("//main//ol/li").size.should eq(20)
    response.body.should_not contain("excluded-provider")
    query_params["login_name"].should eq("targetuser")
    query_params["kind"].should eq("password_signed_in")
    query_params["page"].should eq("2")

    response = ApiClient.new.get(next_path)
    document = XML.parse_html(response.body)

    response.status_code.should eq(200)
    document.xpath_nodes("//main//ol/li").size.should eq(1)
    document.xpath_node("//input[@name='login_name']").not_nil!["value"].should eq("targetuser")
    document.xpath_node("//select/option[@selected]").not_nil!["value"].should eq("password_signed_in")
    document.xpath_node("//main//form//input[@name='page']").should be_nil
  end

  it "does not apply site-wide filters to personal histories or expose them to ordinary users" do
    admin = UserFactory.create &.email("audit-filter-admin@example.com")
    user = UserFactory.create
    other = UserFactory.create
    SaveUserAudit.create!(user_id: user.id, kind: :oauth_signed_in, oauth_provider: "own-provider")
    SaveUserAudit.create!(user_id: other.id, kind: :password_changed)

    {
      "/user_audits?backdoor_user_id=#{user.id}",
      "/user_audits?backdoor_user_id=#{admin.id}&user_id=#{user.id}",
    }.each do |path|
      response = ApiClient.new.get("#{path}&login_name=#{other.login_name}&kind=password_changed")
      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      document.xpath_nodes("//main//ol/li").size.should eq(1)
      document.xpath_node("//main//ol/li").not_nil!.content.should contain("own-provider")
      document.xpath_node("//main//form[@method='get']").should be_nil
      document.xpath_node("//main//aside").should be_nil
    end

    ApiClient.new.get("/user_audits?kind=unknown&backdoor_user_id=#{user.id}").status_code.should eq(200)
  end
end
