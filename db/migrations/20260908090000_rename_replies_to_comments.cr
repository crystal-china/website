# Old migrations still reference Reply and are compiled before they are squashed.
class Reply < BaseModel
  skip_schema_enforcer

  table :replies do
  end
end

class RenameRepliesToComments::V20260908090000 < Avram::Migrator::Migration::V1
  def migrate
    # These triggers should already be absent after RenameReplyRelations. Removing
    # them again also makes this migration safe for databases repaired manually.
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
    drop_trigger :replies, "assign_reply_floor_before_insert"
    drop_function "assign_reply_floor"

    alter :votes do
      rename_belongs_to :reply, :comment
    end

    execute "ALTER TABLE replies RENAME TO comments"
  end

  def rollback
    execute "ALTER TABLE comments RENAME TO replies"

    alter :votes do
      rename_belongs_to :comment, :reply
    end
  end
end
