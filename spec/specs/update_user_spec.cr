require "../spec_helper"

describe UpdateUser do
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
