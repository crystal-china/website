class CreateUsers::V00000000000001 < Avram::Migrator::Migration::V1
  def migrate
    enable_extension "pgroonga"
    enable_extension "citext"

    create table_for(User) do
      primary_key id : Int64
      add name : String, unique: true
      add avatar : String?
      add email : String, unique: true, case_sensitive: false
      add encrypted_password : String?
      add last_active_at : Time?, index: true
      # Existing and new users receive mentions by default. Disabling this
      # affects only future mention notifications, not replies or history.
      add mention_notifications_enabled : Bool, default: true
      add_timestamps
    end

    # 自动补全使用区分大小写的前缀 LIKE，保持与用户名唯一索引一致。
    # text_pattern_ops 是 PostgreSQL 内置的索引比较规则，适合这种 LIKE '前缀%' 查询
    execute "CREATE INDEX users_name_prefix_index ON users (name text_pattern_ops)"
  end

  def rollback
    drop table_for(User)
    disable_extension "citext"
    execute "DROP EXTENSION IF EXISTS pgroonga"
  end
end
