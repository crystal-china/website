class SetupReplyFloorAssignment::V20260830120100 < Avram::Migrator::Migration::V1
  def migrate
    create_function "next_reply_floor(lock_namespace text, where_sql text, target_id bigint)", <<-SQL, returns: "integer"
      DECLARE
        next_floor integer;
      BEGIN
        PERFORM pg_advisory_xact_lock(
          hashtextextended('reply-floor:' || lock_namespace || ':' || target_id::text, 0)
        );

        EXECUTE format(
          'SELECT COALESCE(MAX(floor), 0) + 1
           FROM replies
           WHERE %s',
          where_sql
        )
        INTO next_floor
        USING target_id;

        RETURN next_floor;
      END;
      SQL

    create_function "assign_reply_floor", <<-SQL
      BEGIN
        IF NEW.reply_id IS NULL THEN
          NEW.floor := next_reply_floor('doc', 'doc_id = $1 AND reply_id IS NULL', NEW.doc_id);
        ELSE
          NEW.floor := next_reply_floor('thread', 'root_reply_id = $1', NEW.root_reply_id);
        END IF;

        RETURN NEW;
      END;
      SQL

    create_trigger(
      table_for(Reply),
      "assign_reply_floor_before_insert",
      "assign_reply_floor",
      on: [:insert]
    )
  end

  def rollback
    drop_trigger table_for(Reply), "assign_reply_floor_before_insert"
    drop_function "assign_reply_floor"
    drop_function "next_reply_floor(text, text, bigint)"
  end
end
