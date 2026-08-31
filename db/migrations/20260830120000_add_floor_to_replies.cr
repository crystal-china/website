class AddFloorToReplies::V20260830120000 < Avram::Migrator::Migration::V1
  def migrate
    alter table_for(Reply) do
      add floor : Int32?
    end
  end

  def rollback
    alter table_for(Reply) do
      remove :floor
    end
  end
end
