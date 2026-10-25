class AddNotificationCountersToUsers::V20261025130000 < Avram::Migrator::Migration::V1
  def migrate : Nil
    alter table_for(User) do
      add notifications_count : Int32, default: 0
      add unread_notifications_count : Int32, default: 0
    end

    # 通知创建后收件人不变；总数随新增/物理删除增减。
    add_counters_for(
      source_table: "notifications",
      source_foreign_key: "user_id",
      target_table: "users",
      target_counter_column: "notifications_count"
    )

    # read_at 为 NULL 时计入；已读/未读切换复用软删除/恢复的增减逻辑。
    add_counters_for(
      source_table: "notifications",
      source_foreign_key: "user_id",
      target_table: "users",
      target_counter_column: "unread_notifications_count",
      soft_delete_column: "read_at"
    )

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

  def rollback : Nil
    remove_counters_for(
      source_table: "notifications",
      target_table: "users",
      target_counter_column: "unread_notifications_count"
    )

    remove_counters_for(
      source_table: "notifications",
      target_table: "users",
      target_counter_column: "notifications_count"
    )

    alter table_for(User) do
      remove :notifications_count
      remove :unread_notifications_count
    end
  end
end
