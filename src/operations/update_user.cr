class UpdateUser < User::SaveOperation
  include UserNameValidations

  permit_columns nickname, login_name, avatar, mention_notifications_enabled
  attribute password : String
  attribute password_confirmation : String
  attribute actor_id : Int64

  # 默认值负责：打开编辑页时，从现有 JSONB 读取内容，填入表单
  attribute tagline : String = record.try(&.profile.tagline)
  attribute bio : String = record.try(&.profile.bio)

  before_save do
    validate_user_names
    validate_avatar_is_a_link
    validate_size_of tagline, max: User::Profile::MAX_TAGLINE_LENGTH
    validate_size_of bio, max: User::Profile::MAX_BIO_LENGTH
    profile.value = User::Profile.new(tagline: tagline.value, bio: bio.value)

    actor = if (id = actor_id.value)
              UserQuery.find(id)
            else
              record
            end

    if (user = record) && actor
      if actor.id != user.id && !actor.admin?
        actor_id.add_error r("validations.admin_required").t
      end

      if login_name.changed? && !actor.admin? && !user.login_name_change_allowed?
        login_name.add_error r("validations.login_name_change_expired").t
      end
    end

    if !password.value.nil?
      validate_confirmation_of password, with: password_confirmation
      validate_size_of(
        password,
        min: PasswordValidations::MIN_PASSWORD_LENGTH,
        max: PasswordValidations::MAX_PASSWORD_LENGTH
      )
      Authentic.copy_and_encrypt password, to: encrypted_password if password.valid?
    end
  end

  after_save user_audit

  private def validate_avatar_is_a_link : Nil
    avatar.value.try do |avatar_value|
      if !avatar_value.starts_with?(%r{https?://})
        avatar.add_error r("validations.avatar_url").t
      end
    end
  end

  private def user_audit(saved_user : User) : Nil
    attributes.select(&.changed?).each do |attribute|
      column_name = attribute.name.to_s

      # Record only public profile changes. Do not audit credentials or future
      # private attributes by default.
      next unless column_name.in? ["nickname", "login_name"]

      SaveUserAudit.create!(
        user_id: saved_user.id,
        actor_id: actor_id.value || saved_user.id,
        kind: UserAudit::Kind::ProfileChanged,
        changed_column_name: column_name,
        from: attribute.original_value.try(&.to_s),
        to: attribute.value.try(&.to_s)
      )
    end

    if encrypted_password.changed?
      SaveUserAudit.create!(
        user_id: saved_user.id,
        actor_id: actor_id.value || saved_user.id,
        kind: UserAudit::Kind::PasswordChanged
      )
    end
  end
end
