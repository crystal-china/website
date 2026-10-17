require "../spec_helper"

private class AuditOAuthProvider < MultiAuth::Provider
  def authorize_uri(scope = nil, state = nil) : String
    "https://example.test/authorize"
  end

  def user(params : Hash(String, String)) : MultiAuth::User
    MultiAuth::User.new(
      "audit_spec", "1", "Audit user", "{}",
      OAuth2::AccessToken::Bearer.new("unused", 3600),
      email: params["code"], nickname: "AuditUser"
    )
  end
end

MultiAuth.config("audit_spec") do |redirect_uri, _|
  AuditOAuthProvider.new(redirect_uri, "", "").as(MultiAuth::Provider)
end

private def audit_oauth_callback(email : String) : HTTP::Client::Response
  client = ApiClient.new
  response = client.get("/multi_auth/audit_spec")
  state = URI.parse(response.headers["Location"]).query_params["state"]
  headers = HTTP::Headers.new
  HTTP::Cookies.from_server_headers(response.headers).add_request_headers(headers)

  client.headers(Cookie: headers["Cookie"])
  client.get("/multi_auth/audit_spec/callback?state=#{state}&code=#{URI.encode_path(email)}")
end

private def audit_page_after_callback(response : HTTP::Client::Response) : String
  headers = HTTP::Headers.new
  HTTP::Cookies.from_server_headers(response.headers).add_request_headers(headers)

  ApiClient.new.headers(Cookie: headers["Cookie"]).get("/me/events").body
end

describe "User events" do
  around_each do |example|
    admin_emails = ENV["ADMIN_EMAILS"]?
    ENV["ADMIN_EMAILS"] = "audit-admin@example.com"

    example.run
  ensure
    if admin_emails
      ENV["ADMIN_EMAILS"] = admin_emails
    else
      ENV.delete("ADMIN_EMAILS")
    end
  end

  it "recreates the audit table as empty event history and can restore the old schema" do
    AppDatabase.transaction do
      AppDatabase.exec "CREATE SCHEMA user_audit_migration_spec"
      AppDatabase.exec "SET LOCAL search_path TO user_audit_migration_spec"
      AppDatabase.exec <<-SQL
        CREATE TABLE user_audits (
          id bigint PRIMARY KEY,
          user_id bigint NOT NULL,
          created_at timestamptz NOT NULL,
          updated_at timestamptz NOT NULL,
          sync_state integer NOT NULL DEFAULT 1,
          changed_column_name text NOT NULL,
          "from" text NOT NULL,
          "to" text NOT NULL
        )
        SQL
      AppDatabase.exec <<-SQL
        INSERT INTO user_audits VALUES
          (1, 10, '2020-01-01', '2020-01-02', 3, 'name', 'Old name', 'New name'),
          (2, 10, '2020-02-01', '2020-02-02', 1, 'password', 'old-secret', 'new-secret')
        SQL

      migration = ConvertUserAuditsToEvents::V20261015120000.new
      migration.migrate
      migration.prepared_statements.each { |statement| AppDatabase.exec(statement) }

      UserAuditQuery.new.any?.should be_false
      # 验证该历史迁移自己的表结构，不使用已包含后续字段的当前 Model。
      AppDatabase.exec "INSERT INTO user_audits (user_id, kind) VALUES (10, 2)"
      AppDatabase.query_one("SELECT changed_column_name, \"from\", \"to\", provider FROM user_audits", as: {String?, String?, String?, String?}).should eq({nil, nil, nil, nil})

      migration.reset_prepared_statements
      migration.rollback
      migration.prepared_statements.each { |statement| AppDatabase.exec(statement) }
      columns = AppDatabase.query_all("SELECT column_name FROM information_schema.columns WHERE table_schema = 'user_audit_migration_spec' AND table_name = 'user_audits'", as: String)

      columns.should contain("sync_state")
      columns.should_not contain("kind")
      columns.should_not contain("provider")
      AppDatabase.query_one("SELECT count(*) FROM user_audits", as: Int64).should eq(0)

      AppDatabase.rollback
    end
  end

  it "keeps every profile change as a separate historical event" do
    user = UserFactory.create
    original_nickname = user.nickname
    user = UpdateUser.update!(user, nickname: "First nickname")
    UpdateUser.update!(user, nickname: "Second nickname")

    audits = UserAuditQuery.new.user_id(user.id).id.asc_order.results

    audits.size.should eq(2)
    audits.map(&.kind).should eq([UserAudit::Kind::ProfileChanged, UserAudit::Kind::ProfileChanged])
    audits.map(&.changed_column_name).should eq(["nickname", "nickname"])
    audits.map(&.from).should eq([original_nickname, "First nickname"])
    audits.map(&.to).should eq(["First nickname", "Second nickname"])
  end

  it "allows removing an avatar without creating an audit event" do
    user = UserFactory.create &.avatar("https://example.com/avatar.png")
    user = UpdateUser.update!(user, avatar: nil)

    user.avatar.should be_nil
    UserQuery.find(user.id).avatar.should be_nil
    UserAuditQuery.new.user_id(user.id).any?.should be_false
  end

  it "records password changes without storing passwords, confirmation, or hashes" do
    user = UserFactory.create
    user = UpdateUser.update!(user, nickname: "Changed nickname", password: "changed-password", password_confirmation: "changed-password")
    audits = UserAuditQuery.new.user_id(user.id).id.asc_order.results
    password_event = audits.find(&.kind.password_changed?).not_nil!
    stored_values = audits.flat_map { |audit| [audit.changed_column_name, audit.from, audit.to, audit.provider] }.compact.join(" ")

    audits.size.should eq(2)
    Authentic.correct_password?(user, "changed-password").should be_true
    password_event.changed_column_name.should be_nil
    password_event.from.should be_nil
    password_event.to.should be_nil
    password_event.provider.should be_nil
    stored_values.should_not contain("changed-password")
    stored_values.should_not contain(user.encrypted_password.not_nil!)
  end

  it "also records changes made through password reset" do
    user = ResetPassword.update!(UserFactory.create, password: "reset-password", password_confirmation: "reset-password")
    audit = UserAuditQuery.new.user_id(user.id).first

    audit.kind.should eq(UserAudit::Kind::PasswordChanged)
    audit.from.should be_nil
    audit.to.should be_nil
    Authentic.correct_password?(user, "reset-password").should be_true
  end

  it "does not record unchanged values or failed updates" do
    user = UserFactory.create
    UpdateUser.update!(user, nickname: user.nickname)
    UpdateUser.update(user, password: "new-password", password_confirmation: "mismatch") do |operation, _|
      operation.saved?.should be_false
    end

    UserAuditQuery.new.user_id(user.id).any?.should be_false
  end

  it "rolls back the event together with the user update" do
    user = UserFactory.create

    AppDatabase.transaction do
      UpdateUser.update!(user, nickname: "Rolled back")
      AppDatabase.rollback
    end

    UserQuery.find(user.id).nickname.should eq(user.nickname)
    UserAuditQuery.new.user_id(user.id).any?.should be_false
  end

  it "rejects credential fields as profile events" do
    user = UserFactory.create

    SaveUserAudit.create(user_id: user.id, kind: UserAudit::Kind::ProfileChanged, changed_column_name: "encrypted_password") do |operation, _|
      operation.saved?.should be_false
    end

    UserAuditQuery.new.user_id(user.id).any?.should be_false
  end

  it "requires the OAuth provider but allows events without field changes" do
    user = UserFactory.create

    SaveUserAudit.create(user_id: user.id, kind: UserAudit::Kind::OauthSignedIn) do |operation, _|
      operation.saved?.should be_false
    end

    audit = SaveUserAudit.create!(user_id: user.id, kind: UserAudit::Kind::OauthSignedIn, provider: "github")

    audit.changed_column_name.should be_nil
    audit.from.should be_nil
    audit.to.should be_nil
    audit.provider.should eq("github")
  end

  it "shows password login events in both languages" do
    user = UserFactory.create
    SaveUserAudit.create!(user_id: user.id, kind: :password_signed_in)

    {"zh-CN" => "密码登录", "en" => "Password sign-in"}.each do |locale, expected|
      response = ApiClient.new.get("/me/events?backdoor_user_id=#{user.id}&locale=#{locale}")
      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      document.xpath_node("//main//ol/li/h2").not_nil!.content.should eq(expected)
    end
  end

  it "records each successful OAuth login to an existing account" do
    user = UserFactory.create
    2.times { audit_oauth_callback(user.email).status_code.should eq(303) }
    audits = UserAuditQuery.new.user_id(user.id).results

    audits.size.should eq(2)
    audits.all?(&.kind.oauth_signed_in?).should be_true
    audits.map(&.provider).should eq(["audit_spec", "audit_spec"])
  end

  it "warns password accounts only on the first recorded OAuth login" do
    user = UserFactory.create

    2.times do |index|
      page = audit_page_after_callback(audit_oauth_callback(user.email))

      if index.zero?
        page.should contain("此账号已设置本站密码")
      else
        page.should_not contain("此账号已设置本站密码")
      end
    end
  end

  it "records the first OAuth login when creating an account" do
    response = audit_oauth_callback("new-oauth-audit@example.com")
    user = UserQuery.new.email("new-oauth-audit@example.com").first
    audit = UserAuditQuery.new.user_id(user.id).first

    response.status_code.should eq(303)
    audit.kind.should eq(UserAudit::Kind::OauthSignedIn)
    audit.provider.should eq("audit_spec")
    user.encrypted_password.should be_nil
    audit_page_after_callback(response).should_not contain("此账号已设置本站密码")
  end

  it "does not record a rejected OAuth callback" do
    response = ApiClient.new.get("/multi_auth/audit_spec/callback?state=invalid&code=ignored")

    response.status_code.should eq(400)
    UserAuditQuery.new.any?.should be_false
  end

  it "shows only the current user's events and paginates the history" do
    user = UserFactory.create
    other = UserFactory.create
    SaveUserAudit.create!(user_id: other.id, kind: UserAudit::Kind::OauthSignedIn, provider: "private-provider")
    21.times do
      SaveUserAudit.create!(user_id: user.id, kind: UserAudit::Kind::OauthSignedIn, provider: "github")
    end

    response = ApiClient.new.get("/me/events?backdoor_user_id=#{user.id}")
    document = XML.parse_html(response.body)

    response.status_code.should eq(200)
    document.xpath_nodes("//main//ol/li").size.should eq(20)
    response.body.should contain("下一页")
    response.body.should_not contain("private-provider")

    response = ApiClient.new.get("/me/events?backdoor_user_id=#{user.id}&page=2")
    XML.parse_html(response.body).xpath_nodes("//main//ol/li").size.should eq(1)
  end

  it "shows relative event times with the full timestamp on hover" do
    user = UserFactory.create
    audit = SaveUserAudit.create!(user_id: user.id, kind: :oauth_signed_in, provider: "github", created_at: Time.utc - 2.hours)
    response = ApiClient.new.get("/me/events?backdoor_user_id=#{user.id}")
    time = XML.parse_html(response.body).xpath_node("//main//ol/li/time").not_nil!

    time.content.should eq(TimeInWords::Helpers(TimeInWords::I18n::ZH_CN).from(time: audit.created_at))
    time["datetime"].should eq(audit.created_at.to_rfc3339)
    time["title"].should eq(audit.created_at.to_local.to_s("%Y-%m-%d %H:%M:%S %z"))
  end

  it "rejects another user's history before looking up the requested account" do
    user = UserFactory.create
    other = UserFactory.create

    {other.id, Int64::MAX}.each do |target_id|
      response = ApiClient.new.get("/me/events?backdoor_user_id=#{user.id}&user_id=#{target_id}")

      response.status_code.should eq(403)
    end
  end

  it "lets admins view a selected user's history and keeps that user on pagination" do
    user = UserFactory.create
    admin = UserFactory.create &.email("audit-admin@example.com")
    SaveUserAudit.create!(user_id: admin.id, kind: UserAudit::Kind::OauthSignedIn, provider: "admin-private")
    21.times do
      SaveUserAudit.create!(user_id: user.id, kind: UserAudit::Kind::OauthSignedIn, provider: "target-provider")
    end

    response = ApiClient.new.get("/me/events?backdoor_user_id=#{admin.id}&user_id=#{user.id}")
    document = XML.parse_html(response.body)
    next_path = document.xpath_node("//nav[@aria-label='账户记录分页']//a[.='下一页']").not_nil!["href"]

    response.status_code.should eq(200)
    document.xpath_nodes("//main//ol/li").size.should eq(20)
    document.xpath_node("//main//h1").not_nil!.content.should eq("账户记录")
    response.body.should contain(user.nickname)
    response.body.should_not contain("admin-private")
    URI.parse(next_path).query_params["user_id"].should eq(user.id.to_s)

    response = ApiClient.new.get(next_path)

    response.status_code.should eq(200)
    XML.parse_html(response.body).xpath_nodes("//main//ol/li").size.should eq(1)
    response.body.should contain("target-provider")

    response = ApiClient.new.get("/me/events?backdoor_user_id=#{admin.id}")

    response.body.should contain("admin-private")
    response.body.should_not contain("target-provider")
  end

  it "requires sign-in to view account history" do
    response = ApiClient.new.get("/me/events")

    response.status_code.should eq(303)
    response.headers["Location"].should contain(SignIns::New.path)
  end

  it "keeps profiles public and shows the history link only to their owner and admins" do
    user = UserFactory.create
    other = UserFactory.create
    admin = UserFactory.create &.email("audit-admin@example.com")

    {nil, other.id, user.id, admin.id}.each do |viewer_id|
      path = "/users/#{user.login_name}/profile"
      path += "?backdoor_user_id=#{viewer_id}" if viewer_id
      response = ApiClient.new.get(path)
      link = XML.parse_html(response.body).xpath_node("//main//a[starts-with(@href, '/me/events')]")

      response.status_code.should eq(200)

      if viewer_id == user.id || viewer_id == admin.id
        link.should_not be_nil
        link.not_nil!["href"].should eq(Me::Events.with(user_id: user.id).path)
      else
        link.should be_nil
      end
    end
  end

  it "shows the last password change on settings and failed form submissions" do
    user = UserFactory.create
    audit = SaveUserAudit.create!(user_id: user.id, kind: UserAudit::Kind::PasswordChanged, created_at: Time.utc(2020, 1, 1))
    SaveUserAudit.create!(user_id: user.id, kind: UserAudit::Kind::OauthSignedIn, provider: "github")
    expected = TimeInWords::Helpers(TimeInWords::I18n::ZH_CN).from(time: audit.created_at)

    response = ApiClient.new.get("/users/#{user.id}/edit?backdoor_user_id=#{user.id}")
    time = XML.parse_html(response.body).xpath_node("//form//p/time").not_nil!

    response.status_code.should eq(200)
    response.body.should contain("上次修改密码：")
    time.content.should eq(expected)
    time["datetime"].should eq(audit.created_at.to_rfc3339)
    time["title"].should eq(audit.created_at.to_local.to_s("%Y-%m-%d %H:%M:%S %z"))

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      response = ApiClient.new.put("/users/#{user.id}?backdoor_user_id=#{user.id}", user: {password: "new-password", password_confirmation: "mismatch"})

      response.status_code.should eq(200)
      XML.parse_html(response.body).xpath_node("//form//p/time").not_nil!.content.should eq(expected)
    end
  end
end
