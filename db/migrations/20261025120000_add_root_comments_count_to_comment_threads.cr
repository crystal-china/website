class AddRootCommentsCountToCommentThreads::V20261025120000 < Avram::Migrator::Migration::V1
  def migrate : Nil
    alter table_for(CommentThread) do
      add root_comments_count : Int32, default: 0
    end

    # 只统计未软删除的根评论；撤回仍占据楼层，也仍参与分页。
    add_soft_delete_counters_for(
      source_table: "comments",
      target_table: "comment_threads",
      target_column: "root_comments_count",
      target_id_column: "comment_thread_id",
      when: "parent_id IS NULL"
    )

    # 与新增字段同一次迁移中回填，避免部署后旧评论区显示为零条。
    execute <<-SQL
      UPDATE comment_threads AS thread
      SET root_comments_count = (
        SELECT COUNT(*) FROM comments
        WHERE comment_thread_id = thread.id
          AND parent_id IS NULL
          AND soft_deleted_at IS NULL
      )
      SQL
  end

  def rollback : Nil
    remove_soft_delete_counters_for(
      source_table: "comments",
      target_table: "comment_threads",
      target_column: "root_comments_count"
    )

    alter table_for(CommentThread) do
      remove :root_comments_count
    end
  end
end
