class SaveUserAudit < UserAudit::SaveOperation
  before_save do
    validate_required user_id, kind

    if kind.value == UserAudit::Kind::ProfileChanged
      validate_required changed_column_name
      validate_inclusion_of changed_column_name, in: ["nickname", "login_name", "avatar"]
    elsif kind.value == UserAudit::Kind::OauthSignedIn
      validate_required provider
    end
  end
end
