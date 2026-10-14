require "../../spec_helper"

describe Users::Show do
  it "allows guests to see public profile fields without exposing the email" do
    user = UserFactory.create &.nickname("公开昵称").login_name("Profile_User")
    response = ApiClient.new.get("/users/profile_user/profile")

    response.status_code.should eq(200)
    response.body.should contain("公开昵称")
    response.body.should contain("@Profile_User")
    response.body.should contain(user.created_at.to_local.to_s("%Y-%m-%d"))
    response.body.should_not contain(user.email)
    response.body.should_not contain("编辑个人资料")
  end

  it "returns 404 for a nonexistent user" do
    ApiClient.new.get("/users/nonexistent_user/profile").status_code.should eq(404)
  end

  it "preserves login names ending in recognized format extensions" do
    UserFactory.create &.login_name("suffix_user").nickname("BASE_PROFILE")

    ["html", "xml", "json", "rss", "txt", "css"].each do |extension|
      user = UserFactory.create &.login_name("suffix_user.#{extension}").nickname("SUFFIX_PROFILE_#{extension}")
      path = Users::Show.with(login_name: user.login_name).path
      response = ApiClient.new.get(path)

      path.should eq("/users/#{user.login_name}/profile")
      response.status_code.should eq(200)
      response.body.should contain(user.nickname)
      response.body.should_not contain("BASE_PROFILE")
      UserMarkdown.render("@#{user.login_name}")[:html].should contain(%(href="#{path}"))
    end
  end

  it "only offers profile editing to the account owner" do
    owner = UserFactory.create
    other = UserFactory.create
    path = Users::Show.with(login_name: owner.login_name).path
    own_profile = ApiClient.new.get("#{path}?backdoor_user_id=#{owner.id}")
    other_profile = ApiClient.new.get("#{path}?backdoor_user_id=#{other.id}")

    own_profile.status_code.should eq(200)
    own_profile.body.should contain("编辑个人资料")
    own_profile.body.should contain("个人主页")
    other_profile.status_code.should eq(200)
    other_profile.body.should_not contain("编辑个人资料")
  end
end
