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

  ApiClient.new.headers(Cookie: headers["Cookie"]).get("/user_audits").body
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

  it "creates the event history schema and can roll back the table" do
    AppDatabase.transaction do
      AppDatabase.exec "CREATE SCHEMA user_audit_migration_spec"
      AppDatabase.exec "SET LOCAL search_path TO user_audit_migration_spec"
      AppDatabase.exec "CREATE TABLE users (id bigint PRIMARY KEY)"

      migration = CreateUserAudit::V20250315162146.new
      migration.migrate
      migration.prepared_statements.each { |statement| AppDatabase.exec(statement) }

      UserAuditQuery.new.any?.should be_false
      AppDatabase.exec "INSERT INTO user_audits (user_id, kind) VALUES (10, 5)"
      AppDatabase.query_one("SELECT changed_column_name, \"from\", \"to\", oauth_provider FROM user_audits", as: {String?, String?, String?, String?}).should eq({nil, nil, nil, nil})
      AppDatabase.exec "INSERT INTO user_audits (user_id, kind, oauth_provider) VALUES (10, 3, 'github')"
      AppDatabase.query_all("SELECT oauth_provider FROM user_audits ORDER BY id", as: String?).should eq([nil, "github"])

      columns = AppDatabase.query_all("SELECT column_name FROM information_schema.columns WHERE table_schema = 'user_audit_migration_spec' AND table_name = 'user_audits'", as: String)

      columns.should_not contain("sync_state")
      columns.should contain("kind")
      columns.should contain("oauth_provider")
      columns.should_not contain("provider")
      columns.should contain("actor_id")

      migration.reset_prepared_statements
      migration.rollback
      migration.prepared_statements.each { |statement| AppDatabase.exec(statement) }

      AppDatabase.query_one("SELECT count(*) FROM information_schema.tables WHERE table_schema = 'user_audit_migration_spec' AND table_name = 'user_audits'", as: Int64).should eq(0)

      AppDatabase.rollback
    end
  end

  it "migrates account references without rewriting events and can restore the old constraints" do
    AppDatabase.transaction do
      AppDatabase.exec "CREATE SCHEMA user_audit_associations_migration_spec"
      AppDatabase.exec "SET LOCAL search_path TO user_audit_associations_migration_spec"
      AppDatabase.exec "CREATE TABLE users (id bigint PRIMARY KEY)"
      AppDatabase.exec "INSERT INTO users VALUES (1), (2)"
      original = CreateUserAudit::V20250315162146.new
      original.migrate
      original.prepared_statements.each { |statement| AppDatabase.exec(statement) }
      AppDatabase.exec "INSERT INTO user_audits (user_id, actor_id, kind) VALUES (2, 1, 5), (999, NULL, 5)"
      before = AppDatabase.query_all("SELECT user_id, actor_id, created_at, updated_at FROM user_audits ORDER BY id", as: {Int64, Int64?, Time, Time})
      migration = AllowMissingUserAuditAccounts::V20261020120000.new
      migration.migrate
      migration.prepared_statements.each { |statement| AppDatabase.exec(statement) }

      AppDatabase.query_all("SELECT user_id, actor_id, created_at, updated_at FROM user_audits ORDER BY id", as: {Int64, Int64?, Time, Time}).should eq(before)
      AppDatabase.query_one(
        "SELECT is_nullable FROM information_schema.columns WHERE table_schema = 'user_audit_associations_migration_spec' AND table_name = 'user_audits' AND column_name = 'user_id'",
        as: String
      ).should eq("YES")
      AppDatabase.query_one("SELECT count(*) FROM pg_constraint WHERE conrelid = 'user_audits'::regclass AND contype = 'f'", as: Int64).should eq(0)

      migration.reset_prepared_statements
      migration.rollback
      migration.prepared_statements.each { |statement| AppDatabase.exec(statement) }

      AppDatabase.query_one(
        "SELECT is_nullable FROM information_schema.columns WHERE table_schema = 'user_audit_associations_migration_spec' AND table_name = 'user_audits' AND column_name = 'user_id'",
        as: String
      ).should eq("NO")
      AppDatabase.exec "DELETE FROM users WHERE id = 1"
      AppDatabase.query_all("SELECT actor_id FROM user_audits ORDER BY id", as: Int64?).should eq([nil, nil])
      AppDatabase.rollback
    end
  end

  it "requires both account IDs when saving events and defaults new events to self-actions" do
    user = UserFactory.create
    audit = SaveUserAudit.create!(user_id: user.id, kind: :password_signed_in)

    audit.actor_id.should eq(user.id)
    SaveUserAudit.create(kind: :password_signed_in) do |operation, _|
      operation.saved?.should be_false
      operation.user_id.errors.should_not be_empty
      operation.actor_id.errors.should_not be_empty
    end
    SaveUserAudit.update(audit, actor_id: nil) do |operation, _|
      operation.saved?.should be_false
      operation.actor_id.errors.should_not be_empty
    end
    UserAuditQuery.find(audit.id).actor_id.should eq(user.id)
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
    password_event = audits.find!(&.kind.password_changed?)
    stored_values = audits.flat_map { |audit| [audit.changed_column_name, audit.from, audit.to, audit.oauth_provider] }.compact.join(" ")

    audits.size.should eq(2)
    Authentic.correct_password?(user, "changed-password").should be_true
    password_event.changed_column_name.should be_nil
    password_event.from.should be_nil
    password_event.to.should be_nil
    password_event.oauth_provider.should be_nil
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

    audit = SaveUserAudit.create!(user_id: user.id, kind: UserAudit::Kind::OauthSignedIn, oauth_provider: "github")

    audit.changed_column_name.should be_nil
    audit.from.should be_nil
    audit.to.should be_nil
    audit.oauth_provider.should eq("github")
  end

  it "shows password login events in both languages" do
    user = UserFactory.create
    SaveUserAudit.create!(user_id: user.id, kind: :password_signed_in)

    {"zh-CN" => "密码登录", "en" => "Password sign-in"}.each do |locale, expected|
      response = ApiClient.new.get("/user_audits?backdoor_user_id=#{user.id}&locale=#{locale}")
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
    audits.map(&.oauth_provider).should eq(["audit_spec", "audit_spec"])
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
    audit.oauth_provider.should eq("audit_spec")
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
    SaveUserAudit.create!(user_id: other.id, kind: UserAudit::Kind::OauthSignedIn, oauth_provider: "private-provider")
    21.times do
      SaveUserAudit.create!(user_id: user.id, kind: UserAudit::Kind::OauthSignedIn, oauth_provider: "github")
    end

    response = ApiClient.new.get("/user_audits?backdoor_user_id=#{user.id}")
    document = XML.parse_html(response.body)

    response.status_code.should eq(200)
    document.xpath_nodes("//main//ol/li").size.should eq(20)
    response.body.should contain("下一页")
    response.body.should_not contain("private-provider")

    response = ApiClient.new.get("/user_audits?backdoor_user_id=#{user.id}&page=2")
    XML.parse_html(response.body).xpath_nodes("//main//ol/li").size.should eq(1)
  end

  it "shows relative event times with the full timestamp on hover" do
    user = UserFactory.create
    audit = SaveUserAudit.create!(user_id: user.id, kind: :oauth_signed_in, oauth_provider: "github", created_at: Time.utc - 2.hours)
    response = ApiClient.new.get("/user_audits?backdoor_user_id=#{user.id}")
    time = XML.parse_html(response.body).xpath_node("//main//ol/li/time").not_nil!

    time.content.should eq(TimeInWords::Helpers(TimeInWords::I18n::ZH_CN).from(time: audit.created_at))
    time["datetime"].should eq(audit.created_at.to_rfc3339)
    time["title"].should eq(audit.created_at.to_local.to_s("%Y-%m-%d %H:%M:%S %z"))
  end

  it "rejects another user's history before looking up the requested account" do
    user = UserFactory.create
    other = UserFactory.create

    {other.id, Int64::MAX}.each do |target_id|
      response = ApiClient.new.get("/user_audits?backdoor_user_id=#{user.id}&user_id=#{target_id}")

      response.status_code.should eq(403)
    end
  end

  it "lets admins view a selected user's history and keeps that user on pagination" do
    user = UserFactory.create
    admin = UserFactory.create &.email("audit-admin@example.com")
    SaveUserAudit.create!(user_id: admin.id, kind: UserAudit::Kind::OauthSignedIn, oauth_provider: "admin-private")
    21.times do
      SaveUserAudit.create!(user_id: user.id, kind: UserAudit::Kind::OauthSignedIn, oauth_provider: "target-provider")
    end

    response = ApiClient.new.get("/user_audits?backdoor_user_id=#{admin.id}&user_id=#{user.id}")
    document = XML.parse_html(response.body)
    next_path = document.xpath_node("//nav[@aria-label='账户记录分页']//a[.='下一页']").not_nil!["href"]

    response.status_code.should eq(200)
    document.xpath_nodes("//main//ol/li").size.should eq(20)
    document.xpath_node("//main//h1").not_nil!.content.should eq("账户记录")
    document.xpath_node("//nav[@id='nav-user-panel']/a[@href='/admin']").not_nil!["class"].should_not contain("is-active")
    response.body.should contain(user.nickname)
    response.body.should_not contain("admin-private")
    URI.parse(next_path).query_params["user_id"].should eq(user.id.to_s)

    response = ApiClient.new.get(next_path)

    response.status_code.should eq(200)
    XML.parse_html(response.body).xpath_nodes("//main//ol/li").size.should eq(1)
    response.body.should contain("target-provider")

    response = ApiClient.new.get("/user_audits?backdoor_user_id=#{admin.id}&user_id=#{admin.id}")

    response.body.should contain("admin-private")
    response.body.should_not contain("target-provider")
  end

  it "requires sign-in to view account history" do
    response = ApiClient.new.get("/user_audits")

    response.status_code.should eq(303)
    response.headers["Location"].should contain(SignIns::New.path)
  end

  it "keeps ordinary users scoped to their own history when no account is specified" do
    user = UserFactory.create
    other = UserFactory.create
    SaveUserAudit.create!(user_id: user.id, kind: :oauth_signed_in, oauth_provider: "own-provider")
    SaveUserAudit.create!(user_id: other.id, kind: :oauth_signed_in, oauth_provider: "other-provider")
    response = ApiClient.new.get("/user_audits?backdoor_user_id=#{user.id}")

    response.status_code.should eq(200)
    response.body.should contain("own-provider")
    response.body.should_not contain("other-provider")
    XML.parse_html(response.body).xpath_node("//main//aside").should be_nil
  end

  it "paginates all accounts' events newest first and links to the page from the admin area" do
    admin = UserFactory.create &.email("audit-admin@example.com")
    users = [UserFactory.create, UserFactory.create, admin]
    21.times do |index|
      SaveUserAudit.create!(
        user_id: users[index % users.size].id,
        actor_id: admin.id,
        kind: :profile_changed,
        changed_column_name: "nickname",
        from: "Old nickname #{index}",
        to: "New nickname #{index}"
      )
    end
    response = ApiClient.new.get("/user_audits?backdoor_user_id=#{admin.id}")
    document = XML.parse_html(response.body)
    rows = document.xpath_nodes("//main//ol/li").to_a
    next_path = document.xpath_node("//nav[@aria-label='账户记录分页']//a[.='下一页']").not_nil!["href"]

    response.status_code.should eq(200)
    rows.size.should eq(20)
    rows.first.content.should contain("Old nickname 20 → New nickname 20")
    rows.last.content.should contain("Old nickname 1 → New nickname 1")
    rows.first.xpath_node("./p[last()]").not_nil!.content.should contain(admin.login_name)
    users.each do |user|
      document.xpath_node("//main//ol/li/p[1]//a[@href='/users/#{user.login_name}/profile']").should_not be_nil
    end
    document.xpath_node("//aside//a[@href='/user_audits']").not_nil!["class"].should contain("bg-gray-900")
    document.xpath_node("//nav[@id='nav-user-panel']/a[@href='/admin']").not_nil!["class"].should contain("is-active")
    URI.parse(next_path).path.should eq("/user_audits")

    response = ApiClient.new.get(next_path)
    rows = XML.parse_html(response.body).xpath_nodes("//main//ol/li").to_a

    response.status_code.should eq(200)
    rows.size.should eq(1)
    rows.first.content.should contain("Old nickname 0 → New nickname 0")

    UserAuditQuery.new.select_count.should eq(21)
  end

  it "renders all event kinds in both languages and escapes profile values in the admin history" do
    admin = UserFactory.create &.email("audit-admin@example.com")
    user = UserFactory.create
    UserAudit::Kind.values.each do |kind|
      SaveUserAudit.create!(
        user_id: user.id,
        actor_id: admin.id,
        kind: kind,
        changed_column_name: kind.profile_changed? ? "nickname" : nil,
        from: kind.profile_changed? ? "<script>alert(1)</script>" : nil,
        to: kind.profile_changed? ? "New nickname" : nil,
        oauth_provider: kind.oauth_signed_in? ? "github" : nil
      )
    end

    {"zh-CN" => ["修改昵称", "修改密码", "第三方登录", "移除本站密码", "密码登录"],
     "en"    => ["Changed Nickname", "Password changed", "OAuth sign-in", "Local password removed", "Password sign-in"]}.each do |locale, headings|
      response = ApiClient.new.get("/user_audits?locale=#{locale}&backdoor_user_id=#{admin.id}")
      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      document.xpath_nodes("//main//ol/li/h2").map(&.content).should eq(headings.reverse)
      document.xpath_node("//main//ol//script").should be_nil
      document.xpath_node("//main//ol").not_nil!.content.should contain("<script>alert(1)</script> → New nickname")
      response.body.should contain("github")
    end
  end

  it "keeps deleted accounts' events readable in the admin history" do
    admin = UserFactory.create &.email("audit-admin@example.com")
    user = UserFactory.create
    audit = SaveUserAudit.create!(user_id: user.id, kind: :password_signed_in)
    UserQuery.new.id(user.id).delete
    audit = UserAuditQuery.new.id(audit.id).preload_user.preload_actor.first

    audit.user_id.should eq(user.id)
    audit.actor_id.should eq(user.id)
    audit.user.should be_nil
    audit.actor.should be_nil

    {"zh-CN" => "未知或已删除账户 ##{user.id}", "en" => "Unknown or deleted account ##{user.id}"}.each do |locale, label|
      response = ApiClient.new.get("/user_audits?locale=#{locale}&backdoor_user_id=#{admin.id}")
      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      document.xpath_nodes("//main//ol/li").size.should eq(1)
      document.xpath_node("//main//ol/li/p[1]").not_nil!.content.should contain(label)
      document.xpath_node("//main//ol/li/p[last()]").not_nil!.content.should contain(label)
      document.xpath_node("//main//ol/li/p[last()]//a").should be_nil
    end
  end

  it "retains a deleted administrator's ID in both personal and site-wide history" do
    admin = UserFactory.create &.email("audit-admin@example.com")
    user = UserFactory.create
    actor = UserFactory.create
    audit = SaveUserAudit.create!(user_id: user.id, actor_id: actor.id, kind: :password_removed)
    UserQuery.new.id(actor.id).delete

    {"zh-CN" => "未知或已删除账户 ##{actor.id}", "en" => "Unknown or deleted account ##{actor.id}"}.each do |locale, label|
      {nil, user.id}.each do |target_id|
        path = "/user_audits?locale=#{locale}&backdoor_user_id=#{admin.id}"
        path += "&user_id=#{target_id}" if target_id
        response = ApiClient.new.get(path)
        document = XML.parse_html(response.body)

        response.status_code.should eq(200)
        document.xpath_node("//main//ol/li/p[last()]").not_nil!.content.should contain(label)
        document.xpath_node("//main//ol/li/p[last()]//a").should be_nil
        response.body.should contain(user.login_name)
      end
    end

    stored = UserAuditQuery.find(audit.id)

    stored.user_id.should eq(user.id)
    stored.actor_id.should eq(actor.id)
    stored.created_at.should eq(audit.created_at)
    stored.updated_at.should eq(audit.updated_at)
  end

  it "still displays historical events whose actor ID is already unknown" do
    admin = UserFactory.create &.email("audit-admin@example.com")
    user = UserFactory.create
    audit = SaveUserAudit.create!(user_id: user.id, kind: :password_signed_in)
    UserAuditQuery.new.id(audit.id).update(actor_id: nil)

    {"zh-CN" => "未知或账号已删除", "en" => "Unknown or account deleted"}.each do |locale, label|
      response = ApiClient.new.get("/user_audits?locale=#{locale}&backdoor_user_id=#{admin.id}")
      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      document.xpath_node("//main//ol/li/p[last()]").not_nil!.content.should contain(label)
      UserAuditQuery.find(audit.id).actor_id.should be_nil
    end
  end

  it "shows an empty site-wide history in both languages" do
    admin = UserFactory.create &.email("audit-admin@example.com")

    {"zh-CN" => "暂无账户记录。", "en" => "No account history yet."}.each do |locale, message|
      response = ApiClient.new.get("/user_audits?locale=#{locale}&backdoor_user_id=#{admin.id}")

      response.status_code.should eq(200)
      response.body.should contain(message)
      XML.parse_html(response.body).xpath_node("//main//ol").should be_nil
    end
  end

  it "keeps profiles public and shows the history link only to their owner and admins" do
    user = UserFactory.create
    other = UserFactory.create
    admin = UserFactory.create &.email("audit-admin@example.com")

    {nil, other.id, user.id, admin.id}.each do |viewer_id|
      path = "/users/#{user.login_name}/profile"
      path += "?backdoor_user_id=#{viewer_id}" if viewer_id
      response = ApiClient.new.get(path)
      link = XML.parse_html(response.body).xpath_node("//main//a[starts-with(@href, '/user_audits')]")

      response.status_code.should eq(200)

      if viewer_id == user.id || viewer_id == admin.id
        link.should_not be_nil
        link.not_nil!["href"].should eq(UserAudits::Index.with(user_id: user.id).path)
      else
        link.should be_nil
      end
    end
  end

  it "shows the last password change on settings and failed form submissions" do
    user = UserFactory.create
    audit = SaveUserAudit.create!(user_id: user.id, kind: UserAudit::Kind::PasswordChanged, created_at: Time.utc(2020, 1, 1))
    SaveUserAudit.create!(user_id: user.id, kind: UserAudit::Kind::OauthSignedIn, oauth_provider: "github")
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
