class UserAudit < BaseModel
  enum Kind
    ProfileChanged  = 1
    PasswordChanged = 2
    OauthSignedIn   = 3
  end

  table do
    column user_id : Int64
    column kind : UserAudit::Kind
    column changed_column_name : String?
    column from : String?, allow_blank: true
    column to : String?, allow_blank: true
    column provider : String?
  end
end
