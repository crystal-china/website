class User::SaveOperation
  @new_session_version : String?

  def changes : Hash(Symbol, String?)
    fields = super
    # Avram 生成 UPDATE 语句和参数时会多次调用 changes，必须复用同一个版本。
    # 新用户初始版本为 "0"，之后改密码时才轮换
    if fields.has_key?(:encrypted_password)
      fields[:session_version] = @new_session_version ||= Random::Secure.hex(32)
    end

    fields
  end
end
