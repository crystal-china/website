class AddRootCommentsCountToCommentThreads::V20261025120000 < Avram::Migrator::Migration::V1
  def migrate : Nil
    alter table_for(CommentThread) do
      add root_comments_count : Int32, default: 0
    end

    # 只统计未软删除的根评论；撤回仍占据楼层，也仍参与分页。
    add_counters_for(
      source_table: "comments",
      source_foreign_key: "comment_thread_id",
      target_table: "comment_threads",
      target_counter_column: "root_comments_count",
      soft_delete_column: "soft_deleted_at",
      when: "parent_id IS NULL"
    )

    # 与新增字段同一次迁移中回填，避免部署后旧评论区显示为零条。
    rebuild_counter_for(
      source_table: "comments",
      source_foreign_key: "comment_thread_id",
      target_table: "comment_threads",
      target_counter_column: "root_comments_count",
      soft_delete_column: "soft_deleted_at",
      when: "parent_id IS NULL"
    )
  end

  def rollback : Nil
    remove_counters_for(
      source_table: "comments",
      target_table: "comment_threads",
      target_counter_column: "root_comments_count"
    )

    alter table_for(CommentThread) do
      remove :root_comments_count
    end
  end
end
