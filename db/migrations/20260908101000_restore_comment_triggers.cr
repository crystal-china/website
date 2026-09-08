class RestoreCommentTriggers::V20260908101000 < Avram::Migrator::Migration::V1
  def migrate
    make_required table_for(Comment), :comment_thread_id

    execute <<-SQL
      ALTER TABLE comments
      DROP CONSTRAINT replies_doc_id_reply_id_check
      SQL

    drop_index table_for(Comment), name: :replies_doc_id_floor_index

    execute <<-SQL
      CREATE UNIQUE INDEX comments_comment_thread_id_floor_index
      ON comments (comment_thread_id, floor)
      WHERE parent_id IS NULL
      SQL

    add_counters_for(
      source_table: "comments",
      target_table: "comments",
      target_column: "children_count",
      target_id_column: "parent_id",
    )

    add_counters_for(
      source_table: "comments",
      target_table: "comments",
      target_column: "descendants_count",
      target_id_column: "root_id",
    )

    create_function "assign_comment_floor", <<-SQL
      BEGIN
        IF NEW.parent_id IS NULL THEN
          UPDATE comment_threads
          SET floor_counter = floor_counter + 1
          WHERE id = NEW.comment_thread_id
          RETURNING floor_counter INTO NEW.floor;
        ELSE
          UPDATE comments
          SET floor_counter = floor_counter + 1
          WHERE id = NEW.root_id
          RETURNING floor_counter INTO NEW.floor;
        END IF;

        RETURN NEW;
      END;
      SQL

    create_trigger(
      table_for(Comment),
      "assign_comment_floor_before_insert",
      "assign_comment_floor",
      on: [:insert]
    )
  end

  def rollback
    drop_trigger table_for(Comment), "assign_comment_floor_before_insert"
    drop_function "assign_comment_floor"

    remove_counters_for(
      source_table: "comments",
      target_table: "comments",
      target_column: "descendants_count",
    )

    remove_counters_for(
      source_table: "comments",
      target_table: "comments",
      target_column: "children_count",
    )

    drop_index table_for(Comment), name: :comments_comment_thread_id_floor_index
    create_index table_for(Comment), [:doc_id, :floor], unique: true

    require_nullability_relation(:exactly_one_non_null, "comments", "doc_id", "parent_id")
    make_optional table_for(Comment), :comment_thread_id
  end
end
