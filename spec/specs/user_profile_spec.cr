require "../spec_helper"

describe "User profiles" do
  it "adds an empty, non-null profile to existing and new rows" do
    AppDatabase.transaction do
      AppDatabase.exec "CREATE SCHEMA user_profile_migration_spec"
      AppDatabase.exec "SET LOCAL search_path TO user_profile_migration_spec"
      AppDatabase.exec "CREATE TABLE users (id bigint PRIMARY KEY)"
      AppDatabase.exec "INSERT INTO users VALUES (1)"

      migration = AddProfileToUsers::V20261017120000.new
      migration.migrate
      migration.prepared_statements.each { |statement| AppDatabase.exec(statement) }
      AppDatabase.exec "INSERT INTO users VALUES (2)"

      AppDatabase.query_all("SELECT profile::text FROM users ORDER BY id", as: String).should eq(["{}", "{}"])
      AppDatabase.query_one("SELECT is_nullable FROM information_schema.columns WHERE table_schema = 'user_profile_migration_spec' AND column_name = 'profile'", as: String).should eq("NO")

      migration.reset_prepared_statements
      migration.rollback
      migration.prepared_statements.each { |statement| AppDatabase.exec(statement) }

      AppDatabase.query_one("SELECT count(*) FROM information_schema.columns WHERE table_schema = 'user_profile_migration_spec' AND column_name = 'profile'", as: Int64).should eq(0)
      AppDatabase.rollback
    end
  end

  it "defaults new users to an empty typed profile" do
    user = UserFactory.create

    user.profile.tagline.should be_nil
    user.profile.bio.should be_nil
    user.profile.to_json.should eq("{}")
  end

  it "edits individual profile fields without clearing omitted fields and records the changes" do
    user = UserFactory.create
    updated = UpdateUser.update!(user, tagline: "推理狂", bio: "喜欢 Crystal 和 Ruby。\n也喜欢开源。")
    operation = UpdateUser.new(updated)

    operation.tagline.value.should eq("推理狂")
    operation.bio.value.should eq(updated.profile.bio)
    user.profile.tagline.should be_nil
    UserAuditQuery.new.user_id(user.id).results.map(&.changed_column_name.not_nil!).sort!.should eq(["bio", "tagline"])

    updated = UpdateUser.update!(updated, tagline: "Crystal 爱好者")

    updated.profile.tagline.should eq("Crystal 爱好者")
    updated.profile.bio.should eq("喜欢 Crystal 和 Ruby。\n也喜欢开源。")
    updated.session_version.should eq(user.session_version)

    audit = UserAuditQuery.new.user_id(user.id).id.desc_order.first
    audit.changed_column_name.should eq("tagline")
    audit.from.should eq("推理狂")
    audit.to.should eq("Crystal 爱好者")
    audit.actor_id.should eq(user.id)

    updated = UpdateUser.update!(updated, tagline: "", bio: "")

    updated.profile.to_json.should eq("{}")
  end

  it "renders saved fields in the editor and escapes public profile text" do
    user = UserFactory.create
    user = UpdateUser.update!(user, tagline: "<script>alert(1)</script>", bio: "<b>Crystal</b>\nRuby")
    response = ApiClient.new.get("/users/#{user.id}/edit?backdoor_user_id=#{user.id}")
    document = XML.parse_html(response.body)

    document.xpath_node("//input[@name='user:tagline']").not_nil!["value"].should eq(user.profile.tagline)
    document.xpath_node("//textarea[@name='user:bio']").not_nil!.content.should eq(user.profile.bio)

    response = ApiClient.new.get(Users::Show.with(login_name: user.login_name).path)
    card = Forum::AuthorCard.new(user: user, current_user: nil).render_to_string

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
    UserAuditQuery.new.user_id(user.id).select_count.should eq(3)
  end
end
