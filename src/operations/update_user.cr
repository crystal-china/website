class UpdateUser < User::SaveOperation
  include UserNameValidations

  permit_columns nickname, login_name, avatar, mention_notifications_enabled
  attribute password : String
  attribute password_confirmation : String

  before_save do
    validate_user_names
    validate_avatar_is_a_link

    if (user = record) && login_name.changed? && !user.login_name_change_allowed?
      login_name.add_error Rosetta.find("avram.errors.login_name_change_expired").t
    end

    if !password.value.nil?
      validate_confirmation_of password, with: password_confirmation
      validate_size_of password,
        min: PasswordValidations::MIN_PASSWORD_LENGTH,
        max: PasswordValidations::MAX_PASSWORD_LENGTH
      Authentic.copy_and_encrypt password, to: encrypted_password if password.valid?
    end
  end

  after_save user_audit

  private def validate_avatar_is_a_link : Nil
    avatar.value.try do |avatar_value|
      if !avatar_value.starts_with?(%r{https?://})
        avatar.add_error Rosetta.find("avram.errors.avatar_url").t
      end
    end
  end

  private def user_audit(saved_user : User) : Nil
    attributes.select(&.changed?).each do |attribute|
      column_name = attribute.name.to_s

      # Record only public profile changes. Do not audit credentials or future
      # private attributes by default.
      next unless column_name.in? ["nickname", "login_name", "avatar"]

      SaveUserAudit.create!(
        user_id: saved_user.id,
        kind: UserAudit::Kind::ProfileChanged,
        changed_column_name: column_name,
        from: attribute.original_value.try(&.to_s),
        to: attribute.value.try(&.to_s)
      )
    end

    if encrypted_password.changed?
      SaveUserAudit.create!(user_id: saved_user.id, kind: UserAudit::Kind::PasswordChanged)
    end
  end
end
