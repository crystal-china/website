class UpdateUser < User::SaveOperation
  include UserNameValidations

  permit_columns nickname, login_name, avatar, mention_notifications_enabled, hide_online_status
  attribute password : String
  attribute password_confirmation : String
  attribute actor_id : Int64

  # 默认值负责：打开编辑页时，从现有 JSONB 读取内容，填入表单
  attribute tagline : String = record.try(&.profile.tagline)
  attribute bio : String = record.try(&.profile.bio)

  before_save do
    validate_user_names
    validate_avatar_is_a_link
    validate_and_assign_profile
    validate_profile_edit_permissions
    validate_and_encrypt_password
  end

  after_save do |saved_user|
    record_profile_changes(saved_user)
    record_password_change(saved_user)
    hide_online_presence_if_needed(saved_user)
  end

  private def validate_avatar_is_a_link : Nil
    avatar.value.try do |avatar_value|
      if !avatar_value.starts_with?(%r{https?://})
        avatar.add_error r("validations.avatar_url").t
      end
    end
  end

  private def validate_and_assign_profile : Nil
    validate_size_of tagline, max: User::Profile::MAX_TAGLINE_LENGTH
    validate_size_of bio, max: User::Profile::MAX_BIO_LENGTH

    profile.value = User::Profile.new(tagline: tagline.value, bio: bio.value)
  end

  # 检查操作者能否编辑目标用户，以及是否允许修改登录用户名。
  private def validate_profile_edit_permissions : Nil
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
  end

  # 提供了新密码时，校验确认值和长度，并生成用于保存的密码哈希。
  private def validate_and_encrypt_password : Nil
    return if password.value.nil?

    validate_confirmation_of password, with: password_confirmation
    validate_size_of(
      password,
      min: PasswordValidations::MIN_PASSWORD_LENGTH,
      max: PasswordValidations::MAX_PASSWORD_LENGTH
    )

    Authentic.copy_and_encrypt password, to: encrypted_password if password.valid?
  end

  private def record_profile_changes(saved_user : User) : Nil
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
  end

  private def record_password_change(saved_user : User) : Nil
    return unless encrypted_password.changed?

    SaveUserAudit.create!(
      user_id: saved_user.id,
      actor_id: actor_id.value || saved_user.id,
      kind: UserAudit::Kind::PasswordChanged
    )
  end

  private def hide_online_presence_if_needed(saved_user : User) : Nil
    ONLINE_PRESENCE.hide(saved_user.id) if hide_online_status.changed? && saved_user.hide_online_status?
  end
end
