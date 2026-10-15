require "../spec_helper"

describe SignInUser do
  it "accepts email addresses and case-insensitive login names" do
    user = UserFactory.create &.login_name("Billy").email("billy@example.com").nickname("Billy Zheng")

    ["billy@example.com", "BILLY@EXAMPLE.COM", "Billy", "bIlLy", "  Billy  ", "  billy@example.com  "].each do |login|
      SignInUser.run(login: login, password: "password") do |operation, authenticated_user|
        operation.valid?.should be_true
        authenticated_user.not_nil!.id.should eq(user.id)
      end
    end
  end

  it "rejects nicknames, missing accounts and incorrect passwords with the same message" do
    UserFactory.create &.login_name("Billy").nickname("DisplayName")

    [{"Billy", "wrong"}, {"DisplayName", "password"}, {"MissingUser", "password"}, {"missing@example.com", "password"}, {"", "password"}, {"Billy", ""}].each do |login, password|
      SignInUser.run(login: login, password: password) do |operation, authenticated_user|
        authenticated_user.should be_nil
        operation.errors[:login].should eq([Rosetta.find("avram.errors.credentials_incorrect").t])
      end
    end
  end

  it "does not alter password whitespace" do
    user = UserFactory.create do |factory|
      factory.login_name("Billy")
      factory.encrypted_password(Authentic.generate_encrypted_password(" password "))
    end

    SignInUser.run(login: "Billy", password: " password ") do |_, authenticated_user|
      authenticated_user.not_nil!.id.should eq(user.id)
    end

    SignInUser.run(login: "Billy", password: "password") do |_, authenticated_user|
      authenticated_user.should be_nil
    end
  end

  it "requires a password for OAuth-only accounts" do
    user = OAuthUser.create!(email: "oauth@example.com", nickname: "Billy Zheng", login_name: "Billy")

    [user.email, user.login_name].each do |login|
      SignInUser.run(login: login, password: "password") do |_, authenticated_user|
        authenticated_user.should be_nil
      end
    end

    UpdateUser.update!(user, password: "password", password_confirmation: "password")

    SignInUser.run(login: "billy", password: "password") do |_, authenticated_user|
      authenticated_user.not_nil!.id.should eq(user.id)
    end
  end

  it "renders a text account input and localized login errors" do
    client = ApiClient.new
    response = client.get("/sign_in")
    response.status_code.should eq(200)
    document = XML.parse_html(response.body)
    login = document.xpath_node("//input[@name='user:login']").not_nil!

    login["type"].should eq("text")
    login["autocomplete"].should eq("username")
    document.xpath_node("//input[@name='user:email']").should be_nil

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      response = client.post("/sign_in", user: {login: "MissingUser", password: "wrong"})

      response.status_code.should eq(200)
      response.body.should contain("登录信息 不正确，请检查邮箱、用户名或密码")
    end
  end

  it "signs in through the form using either email or login name" do
    user = UserFactory.create &.login_name("Billy")

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      [user.email, "bIlLy"].each do |login|
        response = ApiClient.new.post("/sign_in", user: {login: login, password: "password"})

        response.status_code.should eq(303)
        response.headers["Location"].should eq(Home::Index.path)
      end
    end
  end

  it "keeps password reset email-only" do
    user = UserFactory.create &.login_name("Billy")

    RequestPasswordReset.run(email: user.email) do |_, found_user|
      found_user.not_nil!.id.should eq(user.id)
    end

    RequestPasswordReset.run(email: user.login_name) do |_, found_user|
      found_user.should be_nil
    end
  end
end
