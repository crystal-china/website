class CreatHourlyAvailabilities::V20250702180203 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(HourlyAvailability) do
      primary_key id : Int64
      add date : String
      add hour : String
      add available : Bool, default: true
      add comment : String?

      add_timestamps
    end
  end

  def rollback
    drop table_for(HourlyAvailability)
  end
end
