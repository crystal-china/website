class AddReplyIntegrityConstraints::V20260830120400 < Avram::Migrator::Migration::V1
  def migrate
    execute "ALTER TABLE replies ADD CONSTRAINT replies_target_check CHECK ((doc_id IS NULL) <> (reply_id IS NULL))"
    execute "ALTER TABLE replies ADD CONSTRAINT replies_thread_check CHECK ((reply_id IS NULL) = (root_reply_id IS NULL))"
  end

  def rollback
    execute "ALTER TABLE replies DROP CONSTRAINT replies_thread_check"
    execute "ALTER TABLE replies DROP CONSTRAINT replies_target_check"
  end
end
