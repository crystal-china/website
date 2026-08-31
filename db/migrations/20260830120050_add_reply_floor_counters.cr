class AddReplyFloorCounters::V20260830120050 < Avram::Migrator::Migration::V1
  def migrate
    alter table_for(Doc) do
      add reply_floor_counter : Int32, default: 0
    end

    alter table_for(Reply) do
      add reply_floor_counter : Int32, default: 0
    end
  end

  def rollback
    alter table_for(Reply) do
      remove :reply_floor_counter
    end

    alter table_for(Doc) do
      remove :reply_floor_counter
    end
  end
end
