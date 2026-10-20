class UserAudit < BaseModel
  enum Kind
    ProfileChanged   = 1
    PasswordChanged  = 2
    OauthSignedIn    = 3
    PasswordRemoved  = 4
    PasswordSignedIn = 5
  end

  table do
    # 这里假设，即使用户，操作者被物理删除，user_audit 也会保留 ID 记录不清空
    # 因此数据库不创建外键约束，且字段可空。
    # belongs_to 也必须可空, 否则，预加载时找不到用户，会抛 MissingRequiredAssociationError。
    belongs_to user : User?
    belongs_to actor : User?

    column kind : UserAudit::Kind
    column changed_column_name : String?
    column from : String?, allow_blank: true
    column to : String?, allow_blank: true
    column oauth_provider : String?
  end
end
