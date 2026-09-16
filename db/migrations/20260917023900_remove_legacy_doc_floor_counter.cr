class RemoveLegacyDocFloorCounter::V20260917023900 < Avram::Migrator::Migration::V1
  def migrate
    # 旧数据库仍有该字段，squash migration 创建的新数据库则没有。
    execute "ALTER TABLE docs DROP COLUMN IF EXISTS floor_counter"
  end

  def rollback
    execute "ALTER TABLE docs ADD COLUMN IF NOT EXISTS floor_counter integer NOT NULL DEFAULT 0"
  end
end
