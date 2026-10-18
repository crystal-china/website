require "../spec_helper"

describe "User profiles" do
  it "creates users with an empty required profile, a session version and normalized login identity" do
    AppDatabase.transaction do
      AppDatabase.exec "CREATE SCHEMA user_profile_migration_spec"
      AppDatabase.exec "SET LOCAL search_path TO user_profile_migration_spec, public"

      migration = CreateUsers::V00000000000001.new
      migration.migrate
      migration.prepared_statements.each { |statement| AppDatabase.exec(statement) }
      AppDatabase.exec "INSERT INTO users (nickname, login_name, email) VALUES ('Same nickname', 'Billy', 'first@example.com'), ('Same nickname', 'Crystalist', 'second@example.com')"

      AppDatabase.query_all("SELECT profile::text FROM users ORDER BY id", as: String).should eq(["{}", "{}"])
      AppDatabase.query_one("SELECT is_nullable FROM information_schema.columns WHERE table_schema = 'user_profile_migration_spec' AND column_name = 'profile'", as: String).should eq("NO")
      AppDatabase.query_all("SELECT session_version FROM users ORDER BY id", as: String).should eq(["0", "0"])
      AppDatabase.query_all("SELECT login_name_lower FROM users ORDER BY id", as: String).should eq(["billy", "crystalist"])
      AppDatabase.query_one("SELECT is_generated FROM information_schema.columns WHERE table_schema = 'user_profile_migration_spec' AND column_name = 'login_name_lower'", as: String).should eq("ALWAYS")
      indexes = AppDatabase.query_all("SELECT indexname FROM pg_indexes WHERE schemaname = 'user_profile_migration_spec' AND tablename = 'users'", as: String)

      indexes.should contain("users_login_name_lower_index")
      indexes.should contain("users_login_name_lower_prefix_index")
      AppDatabase.rollback
    end
  end

  it "defaults new users to an empty typed profile" do
    user = UserFactory.create

    user.profile.tagline.should be_nil
    user.profile.bio.should be_nil
    user.profile.to_json.should eq("{}")
  end

  it "edits individual profile fields without clearing omitted fields or creating audit events" do
    user = UserFactory.create
    updated = UpdateUser.update!(user, tagline: "推理狂", bio: "喜欢 Crystal 和 Ruby。\n也喜欢开源。")
    operation = UpdateUser.new(updated)

    operation.tagline.value.should eq("推理狂")
    operation.bio.value.should eq(updated.profile.bio)
    user.profile.tagline.should be_nil

    updated = UpdateUser.update!(updated, tagline: "Crystal 爱好者")

    updated.profile.tagline.should eq("Crystal 爱好者")
    updated.profile.bio.should eq("喜欢 Crystal 和 Ruby。\n也喜欢开源。")
    updated.session_version.should eq(user.session_version)

    updated = UpdateUser.update!(updated, tagline: "", bio: "")

    updated.profile.to_json.should eq("{}")
    UserAuditQuery.new.user_id(user.id).any?.should be_false
  end

  it "renders saved fields in the editor and escapes public profile text" do
    user = UserFactory.create
    user = UpdateUser.update!(user, tagline: "<script>alert(1)</script>", bio: "<b>Crystal</b>\nRuby")
    response = ApiClient.new.get("/users/#{user.id}/edit?backdoor_user_id=#{user.id}")
    document = XML.parse_html(response.body)

    document.xpath_node("//input[@name='user:tagline']").not_nil!["value"].should eq(user.profile.tagline)
    document.xpath_node("//textarea[@name='user:bio']").not_nil!.content.should eq(user.profile.bio)

    response = ApiClient.new.get(Users::Show.with(login_name: user.login_name).path)
    card = Forum::AuthorCard.new(user: user, current_user: nil).context(time_zone_context).render_to_string

    {response.body, card}.each do |html|
      html.should contain("&lt;script&gt;alert(1)&lt;/script&gt;")
      html.should_not contain("<script>alert(1)</script>")
    end
    response.body.should contain("&lt;b&gt;Crystal&lt;/b&gt;")
  end

  it "validates lengths and retains submitted profile text after a failed save" do
    user = UserFactory.create
    tagline = "签" * (User::Profile::MAX_TAGLINE_LENGTH + 1)
    bio = "介" * (User::Profile::MAX_BIO_LENGTH + 1)

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      response = ApiClient.new.put("/users/#{user.id}?backdoor_user_id=#{user.id}", user: {tagline: tagline, bio: bio})
      document = XML.parse_html(response.body)

      response.status_code.should eq(200)
      document.xpath_node("//input[@name='user:tagline']").not_nil!["value"].should eq(tagline)
      document.xpath_node("//textarea[@name='user:bio']").not_nil!.content.should eq(bio)
      response.body.should contain("签名 长度不能超过")
      response.body.should contain("个人介绍 长度不能超过")
    end

    UserQuery.find(user.id).profile.to_json.should eq("{}")
    UserAuditQuery.new.user_id(user.id).any?.should be_false

    updated = UpdateUser.update!(user, tagline: "签" * User::Profile::MAX_TAGLINE_LENGTH, bio: "介" * User::Profile::MAX_BIO_LENGTH)
    updated.profile.tagline.not_nil!.size.should eq(User::Profile::MAX_TAGLINE_LENGTH)
    updated.profile.bio.not_nil!.size.should eq(User::Profile::MAX_BIO_LENGTH)
  end

  it "does not accept the whole JSON profile from a form" do
    user = UserFactory.create
    user = UpdateUser.update!(user, tagline: "原签名", bio: "原介绍")

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      response = ApiClient.new.put("/users/#{user.id}?backdoor_user_id=#{user.id}", user: {profile: %({"tagline":"forged"}), nickname: "Updated"})

      response.status_code.should eq(303)
    end

    updated = UserQuery.find(user.id)
    updated.profile.should eq(user.profile)
    updated.nickname.should eq("Updated")
    UserAuditQuery.new.user_id(user.id).select_count.should eq(1)
  end
end
