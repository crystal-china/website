class ConvertUserAuditsToEvents::V20261015120000 < Avram::Migrator::Migration::V1
  def migrate : Nil
    drop table_for(UserAudit)

    create table_for(UserAudit) do
      primary_key id : Int64
      add_timestamps

      add user_id : Int64
      add kind : Int32
      add changed_column_name : String?
      add from : String?
      add to : String?
      add provider : String?
    end

    create_index table_for(UserAudit), [:user_id, :id]
  end

  def rollback : Nil
    drop table_for(UserAudit)

    create table_for(UserAudit) do
      primary_key id : Int64
      add_timestamps

      add sync_state : Int32, index: true, default: 1
      add user_id : Int64
      add changed_column_name : String
      add from : String
      add to : String
    end

    create_index table_for(UserAudit), [:sync_state, :user_id, :changed_column_name]
  end
end
