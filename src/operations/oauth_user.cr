class OAuthUser < User::SaveOperation
  permit_columns email, name, avatar

  before_save do
    validate_uniqueness_of email

    # OAuth 的显示名可能有空格；本站用户名同时用于 @ 提及。
    user_name = name.value.to_s.gsub(/[\s\p{Z}]+/, "")
    user_name = "User#{rand(100000..999999)}" if user_name.empty?

    while UserQuery.new.name(user_name.not_nil!).any?
      user_name = "#{user_name}#{rand(100..999)}"
    end

    self.name.value = user_name
    validate_username
  end
end
