require "../spec_helper"

private def account_client(response : HTTP::Client::Response) : ApiClient
  headers = HTTP::Headers.new
  HTTP::Cookies.from_server_headers(response.headers).add_request_headers(headers)

  ApiClient.new.headers(Cookie: headers["Cookie"])
end

private def account_sign_in(user : User) : ApiClient
  response = ApiClient.new.post("/sign_in", user: {login: user.login_name, password: "password"})
  response.status_code.should eq(303)

  account_client(response)
end

describe "Account management" do
  around_each do |example|
    admin_emails = ENV["ADMIN_EMAILS"]?
    ENV["ADMIN_EMAILS"] = "account-admin@example.com"

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      example.run
    end
  ensure
    if admin_emails
      ENV["ADMIN_EMAILS"] = admin_emails
    else
      ENV.delete("ADMIN_EMAILS")
    end
  end

  it "backfills historical actors, keeps orphaned events and can roll back the new columns" do
    AppDatabase.transaction do
      AppDatabase.exec "CREATE SCHEMA account_management_migration_spec"
      AppDatabase.exec "SET LOCAL search_path TO account_management_migration_spec"
      AppDatabase.exec "CREATE TABLE users (id bigint PRIMARY KEY)"
      AppDatabase.exec "CREATE TABLE user_audits (id bigint PRIMARY KEY, user_id bigint NOT NULL)"
      AppDatabase.exec "INSERT INTO users VALUES (1)"
      AppDatabase.exec "INSERT INTO user_audits VALUES (1, 1), (2, 999)"

      migration = AddAccountManagementToUsers::V20261016120000.new
      migration.migrate
      migration.prepared_statements.each { |statement| AppDatabase.exec(statement) }

      AppDatabase.query_one("SELECT session_version FROM users", as: String).should eq("0")
      AppDatabase.query_all("SELECT actor_id FROM user_audits ORDER BY id", as: Int64?).should eq([1_i64, nil])
      AppDatabase.exec "DELETE FROM users WHERE id = 1"
      AppDatabase.query_one("SELECT actor_id FROM user_audits WHERE id = 1", as: Int64?).should be_nil
      AppDatabase.query_one("SELECT count(*) FROM user_audits", as: Int64).should eq(2)

      migration.reset_prepared_statements
      migration.rollback
      migration.prepared_statements.each { |statement| AppDatabase.exec(statement) }

      AppDatabase.query_one("SELECT count(*) FROM information_schema.columns WHERE table_schema = 'account_management_migration_spec' AND column_name IN ('actor_id', 'session_version')", as: Int64).should eq(0)

      AppDatabase.rollback
    end
  end

  it "lets admins open the shared editor for another user and bypass the rename deadline" do
    admin = UserFactory.create &.email("account-admin@example.com")
    user = UserFactory.create &.created_at(Time.utc - 30.days)
    client = account_sign_in(admin)
    profile = client.get(Users::Show.with(login_name: user.login_name).path)
    response = client.get("/admin/users/#{user.id}/edit")
    document = XML.parse_html(response.body)

    profile.body.should contain("/admin/users/#{user.id}/edit")
    response.status_code.should eq(200)
    document.xpath_node("//input[@name='user:login_name']").not_nil!["readonly"]?.should be_nil
    document.xpath_node("//form[@action='/admin/users/#{user.id}']").should_not be_nil
    document.xpath_node("//button[@form='remove-user-password']").should_not be_nil
    document.xpath_nodes("//form//form").should be_empty

    response = client.put("/admin/users/#{user.id}", user: {login_name: "RenamedUser", nickname: "New nickname", mention_notifications_enabled: false})
    updated = UserQuery.find(user.id)
    audits = UserAuditQuery.new.user_id(user.id).results

    response.status_code.should eq(303)
    response.headers["Location"].should eq("/users/RenamedUser/profile")
    updated.login_name.should eq("RenamedUser")
    updated.nickname.should eq("New nickname")
    updated.mention_notifications_enabled.should be_false
    UserQuery.find(admin.id).login_name.should eq(admin.login_name)
    audits.size.should eq(2)
    audits.all? { |audit| audit.actor_id == admin.id }.should be_true

    history = client.get("/me/events?user_id=#{user.id}")
    history.body.should contain("操作人：")
    history.body.should contain(admin.login_name)
    history.body.should contain("/users/RenamedUser/profile")
  end

  it "still validates format and uniqueness for administrator renames" do
    admin = UserFactory.create &.email("account-admin@example.com")
    user = UserFactory.create &.created_at(Time.utc - 30.days)
    client = account_sign_in(admin)

    {admin.login_name, "bad name"}.each do |login_name|
      response = client.put("/admin/users/#{user.id}", user: {login_name: login_name})

      response.status_code.should eq(200)
      UserQuery.find(user.id).login_name.should eq(user.login_name)
    end

    UserAuditQuery.new.user_id(user.id).any?.should be_false
  end

  it "blocks normal users from every administrator account endpoint" do
    user = UserFactory.create
    target = UserFactory.create
    client = account_sign_in(user)

    client.get("/admin/users/#{target.id}/edit").status_code.should eq(404)
    client.put("/admin/users/#{target.id}", user: {nickname: "Forged"}).status_code.should eq(404)
    client.post("/admin/users/#{target.id}/remove_password").status_code.should eq(404)
    UserQuery.find(target.id).nickname.should eq(target.nickname)
    UserQuery.find(target.id).encrypted_password.should eq(target.encrypted_password)
    client.get("/me/edit").body.should_not contain("remove-user-password")
  end

  it "does not accept actor IDs or session versions from a profile form" do
    admin = UserFactory.create &.email("account-admin@example.com")
    user = UserFactory.create &.created_at(Time.utc - 30.days)
    client = account_sign_in(user)
    response = client.put("/me/update", user: {login_name: "ForgedLogin", actor_id: admin.id, session_version: "forged"})

    response.body.should contain("仅能在注册后 7 天内修改")
    UserQuery.find(user.id).login_name.should eq(user.login_name)
    UserQuery.find(user.id).session_version.should eq(user.session_version)

    client.put("/me/update", user: {nickname: "Updated", actor_id: admin.id})
    UserAuditQuery.new.user_id(user.id).first.actor_id.should eq(user.id)
  end

  it "keeps the password-changing browser signed in but revokes other browsers and API tokens" do
    user = UserFactory.create
    editor = account_sign_in(user)
    other = account_sign_in(user)
    api = ApiClient.auth(user)
    response = editor.put("/me/update", user: {password: "new-password", password_confirmation: "new-password"})
    updated = UserQuery.find(user.id)

    response.status_code.should eq(303)
    updated.session_version.should_not eq(user.session_version)
    account_client(response).get("/me/edit").status_code.should eq(200)
    other.get("/me/edit").headers["Location"].should contain("/sign_in")
    api.get("/api/me").status_code.should eq(401)
    ApiClient.auth(updated).get("/api/me").status_code.should eq(200)
    UserAuditQuery.new.user_id(user.id).first.actor_id.should eq(user.id)
  end

  it "does not revoke sessions for unrelated changes, blank passwords or failed saves" do
    user = UserFactory.create
    client = account_sign_in(user)

    response = client.put("/me/update", user: {nickname: "Updated", password: "", password_confirmation: ""})
    response.status_code.should eq(303)
    UserQuery.find(user.id).session_version.should eq(user.session_version)
    client.get("/me/edit").status_code.should eq(200)

    client.put("/me/update", user: {password: "new-password", password_confirmation: "mismatch"})
    UserQuery.find(user.id).session_version.should eq(user.session_version)
    client.get("/me/edit").status_code.should eq(200)
  end

  it "keeps CSRF protection working when an expired login visits a public page" do
    user = UserFactory.create
    client = account_sign_in(user)
    original_page = client.get("/")
    token = XML.parse_html(original_page.body).xpath_node("//meta[@name='csrf-token']").not_nil!["content"]

    UpdateUser.update!(user, password: "new-password", password_confirmation: "new-password")

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: true) do
      response = client.get("/")

      response.status_code.should eq(200)
      XML.parse_html(response.body).xpath_node("//meta[@name='csrf-token']").not_nil!["content"].should eq(token)

      cookies = HTTP::Cookies.from_server_headers(response.headers)
      session = Lucky::Session.from_cookie_jar(Lucky::CookieJar.from_request_cookies(cookies))
      session.get?(Authentic.settings.sign_in_key).should be_nil
      session.get?(:session_version).should be_nil

      guest = account_client(response)
      guest.patch("/htmx/online_users").status_code.should eq(403)
      guest.headers("X-CSRF-TOKEN": token).patch("/htmx/online_users").status_code.should eq(200)
      account_client(response).get("/me/edit").status_code.should eq(303)
    end
  end

  it "revokes the target's sessions, not the administrator's, when the admin changes a password" do
    admin = UserFactory.create &.email("account-admin@example.com")
    user = UserFactory.create
    admin_client = account_sign_in(admin)
    user_client = account_sign_in(user)
    response = admin_client.put("/admin/users/#{user.id}", user: {password: "new-password", password_confirmation: "new-password"})

    response.status_code.should eq(303)
    user_client.get("/me/edit").status_code.should eq(303)
    admin_client.get("/admin/users/#{user.id}/edit").status_code.should eq(200)
    UserAuditQuery.new.user_id(user.id).first.actor_id.should eq(admin.id)
  end

  it "removes passwords with a separate event and does not revive older passwordless sessions" do
    admin = UserFactory.create &.email("account-admin@example.com")
    user = UserFactory.create
    client = account_sign_in(admin)
    old_client = account_sign_in(user)
    old_token = UserToken.generate(user)

    response = client.post("/admin/users/#{user.id}/remove_password")
    removed = UserQuery.find(user.id)
    audit = UserAuditQuery.new.user_id(user.id).latest_password_change.not_nil!
    passwordless_token = UserToken.generate(removed)

    response.status_code.should eq(303)
    removed.encrypted_password.should be_nil
    audit.kind.should eq(UserAudit::Kind::PasswordRemoved)
    audit.actor_id.should eq(admin.id)
    old_client.get("/me/edit").status_code.should eq(303)
    UserToken.decode_user_id(old_token).should be_nil
    client.get("/admin/users/#{user.id}/edit").body.should_not contain("remove-user-password")

    version = removed.session_version
    client.post("/admin/users/#{user.id}/remove_password")
    UserQuery.find(user.id).session_version.should eq(version)
    UserAuditQuery.new.user_id(user.id).select_count.should eq(1)

    user = ResetPassword.update!(removed, password: "password", password_confirmation: "password")
    client.post("/admin/users/#{user.id}/remove_password")

    UserQuery.find(user.id).session_version.should_not eq(version)
    UserToken.decode_user_id(passwordless_token).should be_nil
    client.get("/admin/users/#{user.id}/edit").status_code.should eq(200)
  end

  it "also revokes sessions on password reset and common save operations" do
    user = UserFactory.create
    client = account_sign_in(user)
    token = UserToken.generate(user)

    user = ResetPassword.update!(user, password: "new-password", password_confirmation: "new-password")

    client.get("/me/edit").status_code.should eq(303)
    UserToken.decode_user_id(token).should be_nil
    token = UserToken.generate(user)
    User::SaveOperation.update!(user, encrypted_password: Authentic.generate_encrypted_password("other-password"))
    UserToken.decode_user_id(token).should be_nil
  end

  it "rolls back password, version and event together" do
    user = UserFactory.create
    token = UserToken.generate(user)

    AppDatabase.transaction do
      UpdateUser.update!(user, password: "new-password", password_confirmation: "new-password")
      AppDatabase.rollback
    end

    reloaded = UserQuery.find(user.id)
    reloaded.encrypted_password.should eq(user.encrypted_password)
    reloaded.session_version.should eq(user.session_version)
    UserAuditQuery.new.user_id(user.id).any?.should be_false
    UserToken.decode_user_id(token).should eq(user.id)
  end
end
