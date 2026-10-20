class UserAudit < BaseModel
  enum Kind
    ProfileChanged   = 1
    PasswordChanged  = 2
    OauthSignedIn    = 3
    PasswordRemoved  = 4
    PasswordSignedIn = 5
  end

  table do
    # 这里假设，即使用户被物理删除，user_audit 也会保留记录。
    # 因此这里不使用 belongs_to user, 因为预加载时找不到用户，会抛 MissingRequiredAssociationError。
    column user_id : Int64
    belongs_to actor : User?
    column kind : UserAudit::Kind
    column changed_column_name : String?
    column from : String?, allow_blank: true
    column to : String?, allow_blank: true
    column oauth_provider : String?
  end
end
