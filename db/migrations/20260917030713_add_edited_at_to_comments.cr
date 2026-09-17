class AddEditedAtToComments::V20260917030713 < Avram::Migrator::Migration::V1
  def migrate
    # 旧数据库需要补该字段，squash migration 创建的新数据库已经包含。
    execute "ALTER TABLE comments ADD COLUMN IF NOT EXISTS edited_at timestamptz"
  end

  def rollback
    execute "ALTER TABLE comments DROP COLUMN IF EXISTS edited_at"
  end
end
