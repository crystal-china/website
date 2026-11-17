class CreateSpaces::V20260908080000 < Avram::Migrator::Migration::V1
  def migrate : Nil
    create table_for(Space) do
      primary_key id : Int64
      add name : String
      add slug : String, index: true, unique: true
      add topics_count : Int32, default: 0
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
      add_timestamps
    end
  end

  def rollback : Nil
    drop table_for(Space)
  end
end
