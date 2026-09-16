class RemoveLegacyCommentFields::V20260917024730 < Avram::Migrator::Migration::V1
  def migrate
    # 旧数据库仍有这两个字段，squash migration 创建的新数据库则没有。
    execute <<-SQL
      ALTER TABLE comments
      DROP COLUMN IF EXISTS doc_id,
      DROP COLUMN IF EXISTS preferences
      SQL
  end

  def rollback
    execute <<-SQL
      ALTER TABLE comments
      ADD COLUMN IF NOT EXISTS doc_id bigint REFERENCES docs ON DELETE CASCADE,
      ADD COLUMN IF NOT EXISTS preferences jsonb NOT NULL DEFAULT '{}'::jsonb
      SQL
  end
end
