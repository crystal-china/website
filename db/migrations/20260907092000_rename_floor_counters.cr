class RenameFloorCounters::V20260907092000 < Avram::Migrator::Migration::V1
  def migrate
    alter :docs do
      rename :reply_floor_counter, :floor_counter
    end

    alter :replies do
      rename :reply_floor_counter, :floor_counter
    end
  end

  def rollback
    alter :docs do
      rename :floor_counter, :reply_floor_counter
    end

    alter :replies do
      rename :floor_counter, :reply_floor_counter
    end
  end
end
