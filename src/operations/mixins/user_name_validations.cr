module UserNameValidations
  private def validate_user_names
    self.nickname.value = login_name.value if nickname.value.blank?

    validate_required nickname, login_name
    validate_format_of login_name,
      with: UserLoginName::FORMAT,
      message: Rosetta.find("avram.errors.login_name_format").t
    validate_size_of login_name, min: UserLoginName::MIN_LENGTH, max: UserLoginName::MAX_LENGTH

    return unless login_name.valid?

    query = UserQuery.new.with_login_name(login_name.value.not_nil!)

    # 如果正在修改已有用户，检查用户名是否重复时，排除自己。
    # record 是 Avram 的 SaveOperation 自带的属性
    # 新建时可能为 nil.
    if (user = record)
      query = query.id.not.eq(user.id)
    end

    if query.any?
      login_name.add_error Avram.settings.i18n_backend.get(:validate_uniqueness_of)
    end
  end
end
