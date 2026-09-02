class CreateReplies::V20250309142021 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(Reply) do
      primary_key id : Int64
      add_belongs_to doc : Doc?, on_delete: :cascade
      add_belongs_to user : User, on_delete: :cascade
      add_belongs_to reply : Reply?, on_delete: :cascade
      add_belongs_to root_reply : Reply?, on_delete: :cascade
      add thread_replies_count : Int32, default: 0
      add direct_replies_count : Int32, default: 0
      add reply_floor_counter : Int32, default: 0
      add floor : Int32
      add content : String
      add user_name : String
      add user_avatar : String?
      add preferences : JSON::Any
      add vote_counts : JSON::Any
      add_timestamps
    end

    require_nullability_relation(:exactly_one_non_null, "replies", "doc_id", "reply_id")
    require_nullability_relation(:both_null_or_both_non_null, "replies", "reply_id", "root_reply_id")

    create_index table_for(Reply), [:doc_id, :floor], unique: true
    create_index table_for(Reply), [:root_reply_id, :floor], unique: true

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

  def rollback
    drop_trigger table_for(Reply), "assign_reply_floor_before_insert"
    drop_function "assign_reply_floor"

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

    drop table_for(Reply)
  end
end
