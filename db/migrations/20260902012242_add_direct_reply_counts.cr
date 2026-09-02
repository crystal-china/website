class AddDirectReplyCounts::V20260902012242 < Avram::Migrator::Migration::V1
  def migrate
    remove_counters_for(
      source_table: "replies",
      target_table: "replies",
      target_column: "root_replies_count",
    )

    alter table_for(Reply) do
      rename :root_replies_count, :thread_replies_count
      add direct_replies_count : Int32, default: 0
    end

    add_counters_for(
      source_table: "replies",
      target_table: "replies",
      target_column: "thread_replies_count",
      target_id_column: "root_reply_id",
    )

    add_counters_for(
      source_table: "replies",
      target_table: "replies",
      target_column: "direct_replies_count",
      target_id_column: "reply_id",
    )
  end

  def rollback
    remove_counters_for(
      source_table: "replies",
      target_table: "replies",
      target_column: "direct_replies_count",
    )

    remove_counters_for(
      source_table: "replies",
      target_table: "replies",
      target_column: "thread_replies_count",
    )

    alter table_for(Reply) do
      remove :direct_replies_count
      rename :thread_replies_count, :root_replies_count
    end

    add_counters_for(
      source_table: "replies",
      target_table: "replies",
      target_column: "root_replies_count",
      target_id_column: "root_reply_id",
    )
  end
end
