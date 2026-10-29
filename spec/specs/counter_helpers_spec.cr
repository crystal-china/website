require "../spec_helper"

describe Db::CounterHelpers do
  it "rebuilds filtered and unfiltered counters, including zero matches and self-referencing tables" do
    AppDatabase.transaction do
      AppDatabase.exec "CREATE SCHEMA counter_rebuild_spec"
      AppDatabase.exec "SET LOCAL search_path TO counter_rebuild_spec"
      AppDatabase.exec "CREATE TABLE recipients (id bigint PRIMARY KEY, total_count integer NOT NULL DEFAULT 99, unread_count integer NOT NULL DEFAULT 99, updated_at timestamptz NOT NULL DEFAULT now())"
      AppDatabase.exec "CREATE TABLE messages (id bigint PRIMARY KEY, recipient_id bigint REFERENCES recipients(id), read_at timestamptz)"
      AppDatabase.exec "INSERT INTO recipients (id) VALUES (1), (2), (3)"
      AppDatabase.exec "INSERT INTO messages VALUES (1, 1, NULL), (2, 1, now()), (3, 2, now()), (4, NULL, NULL)"
      updated_at = AppDatabase.query_all("SELECT updated_at FROM recipients ORDER BY id", as: Time)
      migration = AddRootCommentsCountToCommentThreads::V20261025120000.new
      migration.rebuild_counter_for(
        source_table: "messages",
        source_foreign_key: "recipient_id",
        target_table: "recipients",
        target_counter_column: "total_count"
      )
      migration.rebuild_counter_for(
        source_table: "messages",
        source_foreign_key: "recipient_id",
        target_table: "recipients",
        target_counter_column: "unread_count",
        when: "read_at IS NULL"
      )
      migration.prepared_statements.each { |statement| AppDatabase.exec(statement) }

      AppDatabase.query_all("SELECT id, total_count, unread_count FROM recipients ORDER BY id", as: {Int64, Int32, Int32}).should eq([
        {1_i64, 2, 1},
        {2_i64, 1, 0},
        {3_i64, 0, 0},
      ])
      AppDatabase.query_all("SELECT updated_at FROM recipients ORDER BY id", as: Time).should eq(updated_at)

      AppDatabase.exec "CREATE TABLE entries (id bigint PRIMARY KEY, parent_id bigint, soft_deleted_at timestamptz, children_count integer NOT NULL DEFAULT 99)"
      AppDatabase.exec "INSERT INTO entries (id, parent_id, soft_deleted_at) VALUES (1, NULL, NULL), (2, 1, NULL), (3, 1, now()), (4, 2, NULL)"
      migration.reset_prepared_statements
      migration.rebuild_counter_for(
        source_table: "entries",
        source_foreign_key: "parent_id",
        target_table: "entries",
        target_counter_column: "children_count",
        soft_delete_column: "soft_deleted_at"
      )
      migration.prepared_statements.each { |statement| AppDatabase.exec(statement) }

      AppDatabase.query_all("SELECT children_count FROM entries ORDER BY id", as: Int32).should eq([1, 1, 0, 0])

      AppDatabase.rollback
    end
  end

  it "counts NULL states in a custom column and removes the generated triggers and functions" do
    AppDatabase.transaction do
      AppDatabase.exec "CREATE SCHEMA counter_helpers_spec"
      AppDatabase.exec "SET LOCAL search_path TO counter_helpers_spec"
      AppDatabase.exec "CREATE TABLE recipients (id bigint PRIMARY KEY, unread_count integer NOT NULL DEFAULT 0)"
      AppDatabase.exec "CREATE TABLE messages (id bigint PRIMARY KEY, recipient_id bigint REFERENCES recipients(id), read_at timestamptz, category text)"
      # 只借用 migration 收集 SQL，不执行它原本的 migrate。
      migration = AddRootCommentsCountToCommentThreads::V20261025120000.new
      migration.add_counters_for(
        source_table: "messages",
        source_foreign_key: "recipient_id",
        target_table: "recipients",
        target_counter_column: "unread_count",
        soft_delete_column: "read_at",
        when: "category = 'reply'"
      )
      migration.prepared_statements.each { |statement| AppDatabase.exec(statement) }
      AppDatabase.exec "INSERT INTO recipients VALUES (1, 0)"
      AppDatabase.exec "INSERT INTO messages VALUES (1, 1, NULL, 'reply'), (2, 1, now(), 'reply'), (3, 1, NULL, 'other'), (4, NULL, NULL, 'reply')"

      AppDatabase.query_one("SELECT unread_count FROM recipients WHERE id = 1", as: Int32).should eq(1)
      AppDatabase.exec "UPDATE messages SET read_at = now() WHERE id = 1"
      AppDatabase.query_one("SELECT unread_count FROM recipients WHERE id = 1", as: Int32).should eq(0)
      AppDatabase.exec "UPDATE messages SET read_at = now()"
      AppDatabase.query_one("SELECT unread_count FROM recipients WHERE id = 1", as: Int32).should eq(0)
      AppDatabase.exec "UPDATE messages SET read_at = NULL WHERE id IN (1, 2)"
      AppDatabase.query_one("SELECT unread_count FROM recipients WHERE id = 1", as: Int32).should eq(2)
      AppDatabase.exec "UPDATE messages SET read_at = now() WHERE id = 2"
      AppDatabase.exec "DELETE FROM messages WHERE id = 2"
      AppDatabase.query_one("SELECT unread_count FROM recipients WHERE id = 1", as: Int32).should eq(1)
      AppDatabase.exec "DELETE FROM messages"
      AppDatabase.query_one("SELECT unread_count FROM recipients WHERE id = 1", as: Int32).should eq(0)

      migration.reset_prepared_statements
      migration.remove_counters_for(
        source_table: "messages",
        target_table: "recipients",
        target_counter_column: "unread_count"
      )
      migration.prepared_statements.each { |statement| AppDatabase.exec(statement) }
      AppDatabase.query_one("SELECT count(*) FROM pg_trigger WHERE tgrelid = 'messages'::regclass AND NOT tgisinternal", as: Int64).should eq(0)
      AppDatabase.query_one("SELECT count(*) FROM pg_proc WHERE pronamespace = 'counter_helpers_spec'::regnamespace", as: Int64).should eq(0)

      AppDatabase.rollback
    end
  end
end
