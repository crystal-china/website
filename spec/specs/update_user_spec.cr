require "../spec_helper"

describe UpdateUser do
  it "rejects whitespace in usernames" do
    user = UserFactory.create
    ["有 空格", "有\t制表符", "有\n换行", "全角　空格"].each do |name|
      UpdateUser.update(user, name: name) do |operation, _|
        operation.saved?.should be_false
        operation.errors[:name].should_not be_empty
      end
    end
    UpdateUser.update!(user, name: "中文用户名").name.should eq("中文用户名")
  end

  it "normalizes OAuth display names before saving a unique username" do
    UserFactory.create &.name("SomeUser")
    user = OAuthUser.create!(email: "oauth@example.com", name: "Some User")
    user.name.should start_with("SomeUser")
    user.name.should_not eq("SomeUser")
    user.name.should_not contain(" ")
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
