class AddTopicCounters::V20261026120000 < Avram::Migrator::Migration::V1
  def migrate : Nil
    alter table_for(Topic) do
      add space_id : Int64, default: Space::DEFAULT_ID, index: true
    end

    create_foreign_key(
      table_for(Topic),
      table_for(Space),
      on_delete: :restrict,
      column: :space_id
    )

    alter table_for(Node) do
      add topics_count : Int32, default: 0
    end

    alter table_for(User) do
      add topics_count : Int32, default: 0
    end

    add_counters_for(
      source_table: "topics",
      source_foreign_key: "space_id",
      target_table: "spaces",
      target_counter_column: "topics_count",
      soft_delete_column: "soft_deleted_at"
    )

    add_counters_for(
      source_table: "topics",
      source_foreign_key: "node_id",
      target_table: "nodes",
      target_counter_column: "topics_count",
      soft_delete_column: "soft_deleted_at"
    )

    add_counters_for(
      source_table: "topics",
      source_foreign_key: "user_id",
      target_table: "users",
      target_counter_column: "topics_count",
      soft_delete_column: "soft_deleted_at"
    )

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

  def rollback : Nil
    remove_counters_for(
      source_table: "topics",
      target_table: "users",
      target_counter_column: "topics_count"
    )

    remove_counters_for(
      source_table: "topics",
      target_table: "nodes",
      target_counter_column: "topics_count"
    )

    remove_counters_for(
      source_table: "topics",
      target_table: "spaces",
      target_counter_column: "topics_count"
    )

    alter table_for(User) do
      remove :topics_count
    end

    alter table_for(Node) do
      remove :topics_count
    end

    alter table_for(Topic) do
      remove :space_id
    end
  end
end
