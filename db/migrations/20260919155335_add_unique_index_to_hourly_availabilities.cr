class AddUniqueIndexToHourlyAvailabilities::V20260919155335 < Avram::Migrator::Migration::V1
  def migrate
    create_index table_for(HourlyAvailability), [:date, :hour], unique: true
  end

  def rollback
    drop_index table_for(HourlyAvailability), [:date, :hour]
  end
end
