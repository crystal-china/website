class AllowMissingUserAuditAccounts::V20261020120000 < Avram::Migrator::Migration::V1
  def migrate : Nil
    make_optional table_for(UserAudit), :user_id
    # 保留原操作者 ID；不再随用户删除而 SET NULL。
    execute "ALTER TABLE user_audits DROP CONSTRAINT user_audits_actor_id_fkey"
  end

  def rollback : Nil
    make_required table_for(UserAudit), :user_id
    execute <<-SQL
      ALTER TABLE user_audits
      ADD FOREIGN KEY (actor_id) REFERENCES users(id) ON DELETE SET NULL
      SQL
  end
end
