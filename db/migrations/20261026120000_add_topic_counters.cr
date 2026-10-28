class AddTopicCounters::V20261026120000 < Avram::Migrator::Migration::V1
  def migrate : Nil
    alter table_for(Topic) do
      add_belongs_to space : Space?, on_delete: :restrict
    end

    # 先添加可空关联，再从已有 Space 回填所有主题，包括软删除记录，最后设为非空。
    execute <<-SQL
      UPDATE topics
      SET space_id = spaces.id
      FROM spaces
      WHERE spaces.slug = 'default'
      SQL

    make_required table_for(Topic), :space_id

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
