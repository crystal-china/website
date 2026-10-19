class CreateUsers::V00000000000001 < Avram::Migrator::Migration::V1
  def migrate : Nil
    enable_extension "pgroonga"
    # case_sensitive: false 会把字段建成 citext, email 在用他。
    enable_extension "citext"

    create table_for(User) do
      primary_key id : Int64
      # 昵称仅用于显示，允许重复和空格；登录身份由 login_name_lower 保证唯一。
      add nickname : String
      add login_name : String
      add avatar : String?
      # 可选的公开资料，未填写时使用空对象。
      add profile : JSON::Any, default: JSON.parse("{}")
      add email : String, unique: true, case_sensitive: false
      add encrypted_password : String?
      # 密码修改或移除时轮换；浏览器会话及 API 令牌必须匹配当前版本。
      add session_version : String, default: "0"
      add last_active_at : Time?, index: true
      # 心跳确认的累计在线秒数，每五分钟写回；不是登录时长，也不补算历史数据。
      add online_seconds : Int64, default: 0_i64
      add hide_online_status : Bool, default: false
      # Existing and new users receive mentions by default. Disabling this
      # affects only future mention notifications, not replies or history.
      add mention_notifications_enabled : Bool, default: true
      add_timestamps
    end

    # PostgreSQL 自动维护小写身份，原始 login_name 保留用户输入的大小写。
    execute <<-SQL
      ALTER TABLE users
      ADD login_name_lower text GENERATED ALWAYS AS (lower(login_name)) STORED NOT NULL
      SQL

    create_index table_for(User), :login_name_lower, unique: true
    # 前缀自动补全与唯一性查询使用同一份小写身份。
    execute "CREATE INDEX users_login_name_lower_prefix_index ON users (login_name_lower text_pattern_ops)"
  end

  def rollback : Nil
    drop table_for(User)
    disable_extension "citext"
    execute "DROP EXTENSION IF EXISTS pgroonga"
  end
end
