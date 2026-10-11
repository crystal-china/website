class User < BaseModel
  include Carbon::Emailable
  include Authentic::PasswordAuthenticatable

  table do
    column email : String
    column name : String
    column avatar : String?
    column last_active_at : Time?
    column mention_notifications_enabled : Bool = true

    # OAuth 登录时密码为空
    column encrypted_password : String?

    has_many comments : Comment, base_query_class: CommentQuery
    has_many topics : Topic, base_query_class: TopicQuery
  end

  def emailable : Carbon::Address
    Carbon::Address.new(email)
  end

  def admin?
    ENV.fetch("ADMIN_EMAILS", "").split(/[\s,]+/).includes?(email)
  end
end
