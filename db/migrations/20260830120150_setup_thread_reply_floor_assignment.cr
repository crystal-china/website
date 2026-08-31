class SetupThreadReplyFloorAssignment::V20260830120150 < Avram::Migrator::Migration::V1
  def migrate
    create_function "assign_thread_reply_floor", <<-SQL
      BEGIN
        UPDATE replies
        SET reply_floor_counter = reply_floor_counter + 1
        WHERE id = NEW.root_reply_id
        RETURNING reply_floor_counter INTO NEW.floor;

        RETURN NEW;
      END;
      SQL

    execute <<-SQL
CREATE TRIGGER assign_thread_reply_floor_before_insert
BEFORE INSERT ON replies
FOR EACH ROW
WHEN (NEW.reply_id IS NOT NULL)
EXECUTE FUNCTION assign_thread_reply_floor();
SQL
  end

  def rollback
    drop_trigger table_for(Reply), "assign_thread_reply_floor_before_insert"
    drop_function "assign_thread_reply_floor"
  end
end
