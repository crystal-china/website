class AddUsernamePrefixIndex::V20261004121000 < Avram::Migrator::Migration::V1
  def migrate
    # 自动补全使用区分大小写的前缀 LIKE，保持与用户名唯一索引一致。
    # text_pattern_ops 是 PostgreSQL 内置的索引比较规则，适合这种 LIKE '前缀%' 查询
    execute "CREATE INDEX users_name_prefix_index ON users (name text_pattern_ops)"
  end

  def rollback
    execute "DROP INDEX users_name_prefix_index"
  end
end
