class Db::Fix::SoftDeleteCounts < LuckyTask::Task
  include Db::CounterHelpers

  summary "Rebuild visible comment counters after enabling soft deletion (safe to rerun)"

  def call : Nil
    AppDatabase.transaction do
      rebuild_counter_for(
        source_table: "comments",
        source_foreign_key: "parent_id",
        target_table: "comments",
        target_counter_column: "children_count",
        soft_delete_column: "soft_deleted_at"
      )

      rebuild_counter_for(
        source_table: "comments",
        source_foreign_key: "root_id",
        target_table: "comments",
        target_counter_column: "descendants_count",
        soft_delete_column: "soft_deleted_at"
      )

      rebuild_counter_for(
        source_table: "comments",
        source_foreign_key: "comment_thread_id",
        target_table: "comment_threads",
        target_counter_column: "root_comments_count",
        soft_delete_column: "soft_deleted_at",
        when: "parent_id IS NULL"
      )
    end

    puts "Visible comment counters rebuilt"
  end

  private def execute(sql : String) : Nil
    AppDatabase.exec(sql)
  end
end
