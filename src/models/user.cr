class User < BaseModel
  skip_schema_enforcer
  include Carbon::Emailable
  include Authentic::PasswordAuthenticatable

  table do
    column email : String
    column name : String
    column avatar : String?
    column last_active_at : Time?

    # OAuth 登录时密码为空
    column encrypted_password : String?

    has_many comments : Comment
  end

  def emailable : Carbon::Address
    Carbon::Address.new(email)
  end
end
