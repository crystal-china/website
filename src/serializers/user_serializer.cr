class UserSerializer < BaseSerializer
  def initialize(@user : User)
  end

  def render : NamedTuple(email: String)
    {email: @user.email}
  end
end
