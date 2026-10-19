class OAuthUser < User::SaveOperation
  include UserNameValidations

  permit_columns email, nickname, login_name, avatar

  before_save do
    validate_uniqueness_of email

    # OAuth 的显示名可能有空格；保留原样，单独生成本站唯一的 @ 标识。
    login_name.value = UserLoginName.generate(login_name.value.presence || nickname.value)
    validate_user_names
  end
end
