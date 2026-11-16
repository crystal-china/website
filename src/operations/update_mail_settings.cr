class UpdateMailSettings < Space::SaveOperation
  permit_columns smtp_host, smtp_port, smtp_tls_mode, smtp_username, email_from

  attribute smtp_password : String
  attribute clear_smtp_password : Bool = false

  # 保存邮件发送 Tab 的 SMTP 参数、加密密码和发件邮箱。
  before_save do
    validate_required smtp_tls_mode
    normalize_mail_fields
    assign_smtp_password
    validate_mail_fields
  end

  private def normalize_mail_fields : Nil
    if (value = smtp_host.value)
      smtp_host.value = value.strip.presence
    end

    if (value = smtp_username.value)
      smtp_username.value = value.strip.presence
    end

    if (value = email_from.value)
      email_from.value = value.strip.presence
    end
  end

  private def assign_smtp_password : Nil
    if clear_smtp_password.value
      encrypted_smtp_password.value = nil
    elsif (password = smtp_password.value) && !password.empty?
      encrypted_smtp_password.value = EncryptedSecret.encrypt(password)
    end
  end

  private def validate_mail_fields : Nil
    # 三项基本配置全部为空时停用邮件发送；凭据可以保留，便于以后重新启用。
    return unless smtp_host.value || smtp_port.value || email_from.value

    validate_required smtp_host, smtp_port, email_from
    validate_format_of(
      smtp_host,
      with: /\A[a-zA-Z0-9][a-zA-Z0-9.-]*\z/,
      allow_nil: true
    )
    validate_format_of(
      email_from,
      with: /\A[^\s@]+@[^\s@]+\.[^\s@]+\z/,
      allow_nil: true
    )

    if (port = smtp_port.value) && !(1..65535).includes?(port)
      smtp_port.add_error r("validations.smtp_port").t
    end

    if smtp_username.value && encrypted_smtp_password.value.nil?
      smtp_password.add_error r("validations.smtp_password_required").t
    elsif encrypted_smtp_password.value && smtp_username.value.nil?
      # 启用 SMTP 认证时，用户名和密码才需要成对提供。
      # - 普通邮箱服务商通常要求用户名和密码／授权码。
      # - 自建的受信内网邮件中继，可以不要求认证。
      validate_required smtp_username
    end
  end
end
