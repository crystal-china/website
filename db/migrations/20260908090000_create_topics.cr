class CreateTopics::V20260908090000 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(Topic) do
      primary_key id : Int64
      add_belongs_to user : User, on_delete: :cascade
      add title : String
      add content : String
      add_timestamps
    end
  end

  def rollback
    drop table_for(Topic)
  end
end
