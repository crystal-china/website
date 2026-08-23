class RemoveDocsRepliesCount::V20260823103000 < Avram::Migrator::Migration::V1
  def migrate
    remove_counters_for(
      source_table: "replies",
      target_table: "docs",
      target_column: "replies_count",
    )

    alter table_for(Doc) do
      remove :replies_count
    end
  end

  def rollback
    alter table_for(Doc) do
      add replies_count : Int32, default: 0
    end

    add_counters_for(
      source_table: "replies",
      target_table: "docs",
      target_column: "replies_count",
      target_id_column: "doc_id",
    )
  end
end
