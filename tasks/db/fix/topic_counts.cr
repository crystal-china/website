class Db::Fix::TopicCounts < LuckyTask::Task
  include Db::CounterHelpers

  summary "Rebuild site, node and author topic counters (safe to rerun; stop writes first)"

  def call : Nil
    AppDatabase.transaction do
      rebuild_counter_for(
        source_table: "topics",
        source_foreign_key: "space_id",
        target_table: "spaces",
        target_counter_column: "topics_count",
        soft_delete_column: "soft_deleted_at"
      )

      rebuild_counter_for(
        source_table: "topics",
        source_foreign_key: "node_id",
        target_table: "nodes",
        target_counter_column: "topics_count",
        soft_delete_column: "soft_deleted_at"
      )

      rebuild_counter_for(
        source_table: "topics",
        source_foreign_key: "user_id",
        target_table: "users",
        target_counter_column: "topics_count",
        soft_delete_column: "soft_deleted_at"
      )
    end

    puts "Topic counters rebuilt"
  end

  private def execute(sql : String) : Nil
    AppDatabase.exec(sql)
  end
end
