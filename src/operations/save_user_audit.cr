class SaveUserAudit < UserAudit::SaveOperation
  before_save do
    validate_required user_id, kind
    actor_id.value = user_id.value if new_record? && actor_id.value.nil?

    if kind.value == UserAudit::Kind::ProfileChanged
      validate_required changed_column_name
      validate_inclusion_of changed_column_name, in: ["nickname", "login_name", "avatar", "tagline", "bio"]
    elsif kind.value == UserAudit::Kind::OauthSignedIn
      validate_required oauth_provider
    end
  end
end
