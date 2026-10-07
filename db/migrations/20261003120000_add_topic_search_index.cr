class AddTopicSearchIndex::V20261003120000 < Avram::Migrator::Migration::V1
  def migrate
    # 标题与正文合并索引，支持跨字段的多关键词查询；软删除主题不参与搜索。
    execute <<-SQL
      CREATE INDEX topics_title_content_pgroonga_index
      ON topics USING pgroonga ((title || ' ' || content))
      WHERE soft_deleted_at IS NULL
      SQL
  end

  def rollback
    drop_index table_for(Topic), name: "topics_title_content_pgroonga_index"
  end
end
