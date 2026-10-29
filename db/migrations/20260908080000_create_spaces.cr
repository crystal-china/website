class CreateSpaces::V20260908080000 < Avram::Migrator::Migration::V1
  def migrate : Nil
    create table_for(Space) do
      primary_key id : Int64
      add name : String
      add slug : String, index: true, unique: true
      add topics_count : Int32, default: 0
      add_timestamps
    end
  end

  def rollback : Nil
    drop table_for(Space)
  end
end
