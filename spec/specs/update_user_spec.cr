require "timecop"
require "../spec_helper"

describe UpdateUser do
  it "allows changing the login name before the registration window closes" do
    user = UserFactory.create

    Timecop.freeze(user.created_at + 7.days - 1.second) do
      user.login_name_change_allowed?.should be_true
      response = ApiClient.new.get("/users/#{user.id}/edit?backdoor_user_id=#{user.id}")
      field = XML.parse_html(response.body).xpath_node("//input[@name='user:login_name']").not_nil!

      field["readonly"]?.should be_nil
      XML.parse_html(response.body).xpath_node("//p[@id='login-name-help']").not_nil!.content.should contain("注册后 7 天内可修改")
      UpdateUser.update!(user, login_name: "ChangedLogin").login_name.should eq("ChangedLogin")
    end
  end

  it "rejects login-name changes at and after seven days without creating an event" do
    user = UserFactory.create

    {7.days, 8.days}.each do |age|
      Timecop.freeze(user.created_at + age) do
        user.login_name_change_allowed?.should be_false
        UpdateUser.update(user, login_name: "ChangedLogin") do |operation, _|
          operation.saved?.should be_false
          operation.errors[:login_name].should contain(Rosetta.find("validations.login_name_change_expired").t)
        end
      end
    end

    UserQuery.find(user.id).login_name.should eq(user.login_name)
    UserAuditQuery.new.user_id(user.id).any?.should be_false
  end

  it "allows other profile and password changes after the login name is fixed" do
    user = UserFactory.create

    Timecop.freeze(user.created_at + 8.days) do
      updated_user = UpdateUser.update!(
        user,
        login_name: user.login_name,
        nickname: "New nickname",
        avatar: "https://example.com/avatar.png",
        password: "new-password",
        password_confirmation: "new-password"
      )

      updated_user.nickname.should eq("New nickname")
      updated_user.avatar.should eq("https://example.com/avatar.png")
      updated_user.encrypted_password.should_not eq(user.encrypted_password)
    end
  end

  it "makes expired login names read-only and rejects forged form submissions" do
    user = UserFactory.create

    Timecop.freeze(user.created_at + 8.days) do
      {"en", "zh-CN"}.each do |locale|
        response = ApiClient.new.get("/users/#{user.id}/edit?locale=#{locale}&backdoor_user_id=#{user.id}")
        document = XML.parse_html(response.body)
        field = document.xpath_node("//input[@name='user:login_name']").not_nil!

        field["readonly"]?.should_not be_nil
        field["aria-describedby"].should eq("login-name-help")
        document.xpath_node("//p[@id='login-name-help']").not_nil!.content.should eq(Rosetta.find("shared.user_profile_form.login_name_help").t)
      end

      Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
        response = ApiClient.new.put("/users/#{user.id}?backdoor_user_id=#{user.id}", user: {login_name: "ForgedLogin"})

        response.body.should contain("仅能在注册后 7 天内修改")
        UserQuery.find(user.id).login_name.should eq(user.login_name)
      end
    end
  end

  it "enforces the same login-name length boundaries on profile updates" do
    user = UserFactory.create

    ["a", "a" * (UserLoginName::MAX_LENGTH + 1)].each do |login_name|
      UpdateUser.update(user, login_name: login_name) do |operation, _|
        operation.saved?.should be_false
        operation.errors[:login_name].should_not be_empty
      end
    end

    [UserLoginName::MIN_LENGTH, UserLoginName::MAX_LENGTH].each do |length|
      user = UpdateUser.update!(user, login_name: "a" * length)

      user.login_name.size.should eq(length)
    end
  end

  it "rejects characters outside the ASCII login-name whitelist" do
    user = UserFactory.create
    ["有 空格", "有\t制表符", "有\n换行", "全角　空格", "小明", "user😀", "O'Neil", "SomeUser(he/him)", "zero\u200bwidth", "_ab_", "__ab", ".ab", "-ab", "ab.", "ab-", "ab__cd", "ab._cd"].each do |name|
      UpdateUser.update(user, login_name: name) do |operation, _|
        operation.saved?.should be_false
        operation.errors[:login_name].should_not be_empty
      end
    end
    UpdateUser.update!(user, login_name: "Some.User_123-test", nickname: "小明 😀").login_name.should eq("Some.User_123-test")
    UserQuery.find(user.id).nickname.should eq("小明 😀")
  end

  it "preserves OAuth display names while generating unique login names" do
    UserFactory.create &.login_name("someuser")
    user = OAuthUser.create!(email: "oauth@example.com", nickname: "Some User")
    user.nickname.should eq("Some User")
    user.login_name.should start_with("SomeUser_")
    user.login_name.should_not contain(" ")
  end

  it "uses the provider login without changing the display name" do
    user = OAuthUser.create!(email: "github@example.com", nickname: "Billy Zheng", login_name: "zw963")
    user.nickname.should eq("Billy Zheng")
    user.login_name.should eq("zw963")
    user.login_name_lower.should eq("zw963")
  end

  it "generates a usable identity when the provider supplies no name" do
    user = OAuthUser.create!(email: "unnamed@example.com")
    user.login_name.should match(/\ACrystalist_[0-9]{6}\z/)
    user.nickname.should eq(user.login_name)
  end

  it "generates a valid login name for a one-character OAuth name" do
    user = OAuthUser.create!(email: "short-oauth@example.com", nickname: "A", login_name: "A")

    user.nickname.should eq("A")
    user.login_name.should match(/\ACrystalist_[0-9]{6}\z/)
    user.login_name.size.in?(UserLoginName::MIN_LENGTH..UserLoginName::MAX_LENGTH).should be_true
  end

  it "generates an ASCII handle while preserving a Chinese OAuth nickname" do
    user = OAuthUser.create!(email: "chinese-oauth@example.com", nickname: "小明 😀")

    user.nickname.should eq("小明 😀")
    user.login_name.should match(/\ACrystalist_[0-9]{6}\z/)
    UserLoginName::FORMAT.matches?(user.login_name).should be_true
  end

  it "limits generated OAuth login names without truncating the nickname" do
    preferred = "LongName" * 10
    UserFactory.create &.login_name(preferred[0, UserLoginName::MAX_LENGTH])
    user = OAuthUser.create!(email: "long-oauth@example.com", nickname: preferred, login_name: preferred)

    user.nickname.should eq(preferred)
    user.login_name.size.should eq(UserLoginName::MAX_LENGTH)
    user.login_name.should start_with(preferred[0, UserLoginName::MAX_LENGTH - 7] + "_")
  end

  it "normalizes OAuth separators and keeps the original display name" do
    {"..Billy__Zheng.-" => "Billy_Zheng", "__Billy..Zheng" => "_Billy_Zheng", "-a-_b-" => "a_b"}.each_with_index do |(preferred, expected), index|
      user = OAuthUser.create!(email: "normalized-oauth-#{index}@example.com", nickname: preferred, login_name: preferred)

      user.nickname.should eq(preferred)
      user.login_name.should eq(expected)
      UserLoginName.valid?(user.login_name).should be_true
    end
  end

  it "does not join two separators when adding a collision suffix" do
    preferred = "a" * 12 + "_" + "b" * 7
    UserFactory.create &.login_name(preferred)
    user = OAuthUser.create!(email: "separator-collision@example.com", login_name: preferred)

    user.login_name.should match(/\Aa{12}_[0-9]{6}\z/)
    UserLoginName.valid?(user.login_name).should be_true
  end

  it "defaults a cleared nickname without changing mention identity" do
    user = UserFactory.create
    user = UpdateUser.update!(user, nickname: "")

    user.nickname.should eq(user.login_name)
    UserQuery.new.with_login_names(UserMarkdown.render("@#{user.login_name}")[:mentions]).id.asc_order.results.map(&.id).should eq([user.id])
  end

  it "allows duplicate display names and keeps mention identity unchanged" do
    first = UpdateUser.update!(UserFactory.create, nickname: "Billy Zheng")
    second = UpdateUser.update!(UserFactory.create, nickname: "Billy Zheng")
    first.login_name.should_not eq(second.login_name)
    UserQuery.new.with_login_names(UserMarkdown.render("@#{first.login_name}")[:mentions]).id.asc_order.results.map(&.id).should eq([first.id])
    UpdateUser.update!(first, nickname: "新 昵称")
    UserQuery.new.with_login_names(UserMarkdown.render("@#{first.login_name}")[:mentions]).id.asc_order.results.map(&.id).should eq([first.id])
    UserQuery.new.with_login_names(UserMarkdown.render("@Billy")[:mentions]).results.should be_empty
  end

  it "rejects duplicate login names and mention delimiters" do
    first = UserFactory.create
    second = UserFactory.create

    [first.login_name, first.login_name.downcase, "invalid@name", "invalid，name"].each do |login_name|
      UpdateUser.update(second, login_name: login_name) do |operation, _|
        operation.saved?.should be_false
        operation.errors[:login_name].should_not be_empty
      end
    end
  end

  it "preserves spelling while resolving mentions case-insensitively" do
    user = UpdateUser.update!(UserFactory.create, login_name: "Billy")
    user.login_name.should eq("Billy")
    user.login_name_lower.should eq("billy")
    UserQuery.new.with_login_names(UserMarkdown.render("@billy @BILLY")[:mentions]).id.asc_order.results.map(&.id).should eq([user.id])
    user = UpdateUser.update!(user, login_name: "bIlLy")
    user.login_name.should eq("bIlLy")
    user.login_name_lower.should eq("billy")

    expect_raises(PQ::PQError) do
      UserFactory.create &.login_name("BILLY")
    end
  end

  it "maintains lowercase identities on direct updates and ignores form overrides" do
    user = UserFactory.create
    UserQuery.new.id(user.id).update(login_name: "MixedCase")
    user = UserQuery.find(user.id)
    user.login_name_lower.should eq("mixedcase")

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      response = ApiClient.new.put("/users/#{user.id}?backdoor_user_id=#{user.id}", user: {login_name_lower: "forged"})
      response.status_code.should eq(303)
    end

    user = UserQuery.find(user.id)
    user.login_name_lower.should eq("mixedcase")
    UserQuery.new.with_login_names(UserMarkdown.render("@MIXEDCASE")[:mentions]).id.asc_order.results.map(&.id).should eq([user.id])
  end

  it "looks up quoted login names safely" do
    user = UpdateUser.update!(UserFactory.create, login_name: "ONeil")
    UserQuery.new.with_login_names(UserMarkdown.render("@o'neil")[:mentions]).results.should be_empty
    UserQuery.new.with_login_names(UserMarkdown.render("@oneil")[:mentions]).id.asc_order.results.map(&.id).should eq([user.id])
  end

  it "rejects passwords outside the shared length range" do
    user = UserFactory.create
    encrypted_password = user.encrypted_password

    {"short", "a" * 73}.each do |password|
      UpdateUser.update(user, password: password, password_confirmation: password) do |operation, _updated_user|
        operation.saved?.should be_false
        operation.errors[:password].should_not be_empty
      end
    end

    UserQuery.find(user.id).encrypted_password.should eq(encrypted_password)
  end
end
