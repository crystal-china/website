class AddSpaceSettings::V20261115235500 < Avram::Migrator::Migration::V1
  def migrate : Nil
    alter table_for(Space) do
      add logo_url : String?
      add contact_email : String?
      add source_url : String?
      add footer_links : JSON::Any?
      add smtp_host : String?
      add smtp_port : Int32?
      # SMTP 连接加密方式；1 表示 STARTTLS。
      add smtp_tls_mode : Int32, default: 1
      add smtp_username : String?
      add encrypted_smtp_password : String?
      add email_from : String?
    end
  end

  def rollback : Nil
    alter table_for(Space) do
      remove :logo_url
      remove :contact_email
      remove :source_url
      remove :footer_links
      remove :smtp_host
      remove :smtp_port
      remove :smtp_tls_mode
      remove :smtp_username
      remove :encrypted_smtp_password
      remove :email_from
    end
  end
end
