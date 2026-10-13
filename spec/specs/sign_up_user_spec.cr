require "../spec_helper"

describe SignUpUser do
  it "accepts a chosen login name and a non-unique nickname" do
    user = SignUpUser.create!(email: "signup@example.com", login_name: "Billy",
      nickname: "Billy Zheng", password: "password", password_confirmation: "password", captcha_code: "sample")
    other = SignUpUser.create!(email: "other-signup@example.com", login_name: "OtherBilly",
      nickname: "Billy Zheng", password: "password", password_confirmation: "password", captcha_code: "sample")

    user.nickname.should eq(other.nickname)
    user.login_name.should eq("Billy")
    user.login_name_lower.should eq("billy")
    Authentic.correct_password?(user, "password").should be_true
  end

  it "defaults an omitted nickname to the chosen login name" do
    user = SignUpUser.create!(email: "default-nickname@example.com", login_name: "ChosenName",
      password: "password", password_confirmation: "password", captcha_code: "sample")

    user.nickname.should eq("ChosenName")
  end

  it "rejects occupied and invalid login names without silently renaming them" do
    UserFactory.create &.login_name("Billy")

    ["bIlLy", "", "a", "有 空格", "小明", "user😀", "invalid@name", "a" * (UserLoginName::MAX_LENGTH + 1)].each do |login_name|
      SignUpUser.create(email: "invalid-signup@example.com", login_name: login_name,
        password: "password", password_confirmation: "password", captcha_code: "sample") do |operation, user|
        user.should be_nil
        operation.errors[:login_name].should_not be_empty
      end
    end

    UserQuery.new.email("invalid-signup@example.com").any?.should be_false
  end

  it "accepts login names at both length boundaries" do
    [UserLoginName::MIN_LENGTH, UserLoginName::MAX_LENGTH].each do |length|
      user = SignUpUser.create!(email: "length-#{length}@example.com", login_name: "a" * length,
        password: "password", password_confirmation: "password", captcha_code: "sample")

      user.login_name.size.should eq(length)
    end
  end

  it "offers a required login name and an optional nickname in the signup form" do
    response = ApiClient.new.get("/sign_up")
    response.status_code.should eq(200)
    document = XML.parse_html(response.body)
    login_name = document.xpath_node("//input[@name='user:login_name']").not_nil!
    nickname = document.xpath_node("//input[@name='user:nickname']").not_nil!

    login_name["required"]?.should_not be_nil
    login_name["minlength"].should eq(UserLoginName::MIN_LENGTH.to_s)
    login_name["maxlength"].should eq(UserLoginName::MAX_LENGTH.to_s)
    nickname["required"]?.should be_nil
  end
end
