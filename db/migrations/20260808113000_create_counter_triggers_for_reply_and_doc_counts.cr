class CreateCounterTriggersForRootReplyCounts::V20260808113000 < Avram::Migrator::Migration::V1
  def migrate
    add_counters_for(
      source_table: "replies",
      target_table: "replies",
      target_column: "root_replies_count",
      target_id_column: "root_reply_id",
    )

    add_counters_for(
      source_table: "replies",
      target_table: "docs",
      target_column: "replies_count",
      target_id_column: "doc_id",
    )
  end

  def rollback
    remove_counters_for(
      source_table: "replies",
      target_table: "replies",
      target_column: "root_replies_count",
    )

    remove_counters_for(
      source_table: "replies",
      target_table: "docs",
      target_column: "replies_count",
    )
  end
end
