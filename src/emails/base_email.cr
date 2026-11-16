# Learn about sending emails
# https://luckyframework.org/guides/emails/sending-emails-with-carbon
abstract class BaseEmail < Carbon::Email
  include Rosetta::Translatable

  class NotConfigured < Exception
  end

  macro inherited
    from default_from
  end

  def default_from : Carbon::Address
    space = Space::BaseQuery.new.id(Space::DEFAULT_ID).first?
    address = space ? space.email_from : nil

    unless address
      raise NotConfigured.new("Configure the sender address in /admin/settings before sending email")
    end

    Carbon::Address.new(address)
  end

  # 将数据库中的 SMTP 设置应用到当前进程的 Carbon adapter，启动和后台保存成功时调用。
  def self.configure_smtp(space : Space?) : Nil
    return unless space && space.smtp_host && space.smtp_port && space.email_from

    Carbon::SmtpAdapter.configure do |settings|
      settings.host = space.smtp_host.not_nil!
      settings.port = space.smtp_port.not_nil!
      settings.username = space.smtp_username
      settings.password = space.encrypted_smtp_password.try { |password| EncryptedSecret.decrypt(password) }
      settings.use_tls = case space.smtp_tls_mode
                         in .starttls?
                           true
                         end
    end
  end
end
