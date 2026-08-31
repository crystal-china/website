class SetupDocReplyFloorAssignment::V20260830120100 < Avram::Migrator::Migration::V1
  def migrate
    create_function "assign_doc_reply_floor", <<-SQL
      BEGIN
        UPDATE docs
        SET reply_floor_counter = reply_floor_counter + 1
        WHERE id = NEW.doc_id
        RETURNING reply_floor_counter INTO NEW.floor;

        RETURN NEW;
      END;
      SQL

    execute <<-SQL
CREATE TRIGGER assign_doc_reply_floor_before_insert
BEFORE INSERT ON replies
FOR EACH ROW
WHEN (NEW.reply_id IS NULL)
EXECUTE FUNCTION assign_doc_reply_floor();
SQL
  end

  def rollback
    drop_trigger table_for(Reply), "assign_doc_reply_floor_before_insert"
    drop_function "assign_doc_reply_floor"
  end
end
