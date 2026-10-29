class Db::Fix::NotificationCounts < LuckyTask::Task
  include Db::CounterHelpers

  summary "Rebuild total and unread notification counters (safe to rerun)"

  def call : Nil
    AppDatabase.transaction do
      rebuild_counter_for(
        source_table: "notifications",
        source_foreign_key: "user_id",
        target_table: "users",
        target_counter_column: "notifications_count"
      )

      rebuild_counter_for(
        source_table: "notifications",
        source_foreign_key: "user_id",
        target_table: "users",
        target_counter_column: "unread_notifications_count",
        soft_delete_column: "read_at"
      )
    end

    puts "Notification counters rebuilt"
  end

  # migration 的 execute 收集 SQL，task 的 execute 则直接执行同一套 helper 生成的 SQL。
  private def execute(sql : String) : Nil
    AppDatabase.exec(sql)
  end
end
