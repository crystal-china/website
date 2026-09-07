class RenameReplyRelations::V20260907090000 < Avram::Migrator::Migration::V1
  def migrate
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
    drop_trigger table_for(Reply), "assign_reply_floor_before_insert"
    drop_function "assign_reply_floor"

    alter :replies do
      rename_belongs_to :reply, :parent
      rename_belongs_to :root_reply, :root
    end
  end

  def rollback
    alter :replies do
      rename_belongs_to :parent, :reply
      rename_belongs_to :root, :root_reply
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

    create_function "assign_reply_floor", <<-SQL
      BEGIN
        IF NEW.reply_id IS NULL THEN
          UPDATE docs
          SET reply_floor_counter = reply_floor_counter + 1
          WHERE id = NEW.doc_id
          RETURNING reply_floor_counter INTO NEW.floor;
        ELSE
          UPDATE replies
          SET reply_floor_counter = reply_floor_counter + 1
          WHERE id = NEW.root_reply_id
          RETURNING reply_floor_counter INTO NEW.floor;
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
end
