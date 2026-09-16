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

    # migration 合并前，生产库使用两个独立的楼层 trigger。
    drop_trigger table_for(Reply), "assign_doc_reply_floor_before_insert"
    drop_trigger table_for(Reply), "assign_thread_reply_floor_before_insert"
    drop_function "assign_doc_reply_floor"
    drop_function "assign_thread_reply_floor"

    drop_nullability_relation(:exactly_one_non_null, "replies", "doc_id", "reply_id")
    drop_nullability_relation(:both_null_or_both_non_null, "replies", "reply_id", "root_reply_id")

    # 引入 nullability helper 前，生产库使用下面两个约束名称。
    execute "ALTER TABLE replies DROP CONSTRAINT IF EXISTS replies_target_check"
    execute "ALTER TABLE replies DROP CONSTRAINT IF EXISTS replies_thread_check"

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

    require_nullability_relation(:exactly_one_non_null, "replies", "doc_id", "reply_id")
    require_nullability_relation(:both_null_or_both_non_null, "replies", "reply_id", "root_reply_id")

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
