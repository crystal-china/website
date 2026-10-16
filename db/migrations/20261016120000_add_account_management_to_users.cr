class AddAccountManagementToUsers::V20261016120000 < Avram::Migrator::Migration::V1
  def migrate : Nil
    alter table_for(User) do
      # 密码修改或移除时轮换；浏览器会话及 API 令牌必须匹配当前版本。
      add session_version : String, default: "0"
    end

    alter table_for(UserAudit) do
      # 操作者可以与被修改用户不同；删除操作者账号仍保留事件。
      add_belongs_to actor : User?, on_delete: :nullify, index: false
    end

    # 此前只支持本人修改；无法找到的历史账号保持未知操作者。
    execute <<-SQL
      UPDATE user_audits SET actor_id = user_id
      WHERE EXISTS (SELECT 1 FROM users WHERE users.id = user_audits.user_id)
      SQL
  end

  def rollback : Nil
    alter table_for(UserAudit) do
      remove :actor_id
    end

    alter table_for(User) do
      remove :session_version
    end
  end
end
