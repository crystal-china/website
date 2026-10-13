require "../spec_helper"

describe UpdateUser do
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
    ["有 空格", "有\t制表符", "有\n换行", "全角　空格", "小明", "user😀", "O'Neil", "SomeUser(he/him)", "zero\u200bwidth"].each do |name|
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
    user.login_name.should start_with("User")
    user.nickname.should eq(user.login_name)
  end

  it "generates a valid login name for a one-character OAuth name" do
    user = OAuthUser.create!(email: "short-oauth@example.com", nickname: "A", login_name: "A")

    user.nickname.should eq("A")
    user.login_name.should start_with("User")
    user.login_name.size.in?(UserLoginName::MIN_LENGTH..UserLoginName::MAX_LENGTH).should be_true
  end

  it "generates an ASCII handle while preserving a Chinese OAuth nickname" do
    user = OAuthUser.create!(email: "chinese-oauth@example.com", nickname: "小明 😀")

    user.nickname.should eq("小明 😀")
    user.login_name.should start_with("User")
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

  it "defaults a cleared nickname without changing mention identity" do
    user = UserFactory.create
    user = UpdateUser.update!(user, nickname: "")

    user.nickname.should eq(user.login_name)
    UserMentions.user_ids("@#{user.login_name}").should eq([user.id])
  end

  it "allows duplicate display names and keeps mention identity unchanged" do
    first = UpdateUser.update!(UserFactory.create, nickname: "Billy Zheng")
    second = UpdateUser.update!(UserFactory.create, nickname: "Billy Zheng")
    first.login_name.should_not eq(second.login_name)
    UserMentions.user_ids("@#{first.login_name}").should eq([first.id])
    UpdateUser.update!(first, nickname: "新 昵称")
    UserMentions.user_ids("@#{first.login_name}").should eq([first.id])
    UserMentions.user_ids("@Billy").should be_empty
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
    UserMentions.user_ids("@billy @BILLY").should eq([user.id])
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
      response = ApiClient.new.put("/me/update?backdoor_user_id=#{user.id}", user: {login_name_lower: "forged"})
      response.status_code.should eq(303)
    end

    user = UserQuery.find(user.id)
    user.login_name_lower.should eq("mixedcase")
    UserMentions.user_ids("@MIXEDCASE").should eq([user.id])
  end

  it "looks up quoted login names safely" do
    user = UpdateUser.update!(UserFactory.create, login_name: "ONeil")
    UserMentions.user_ids("@o'neil").should be_empty
    UserMentions.user_ids("@oneil").should eq([user.id])
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
