class AddHideOnlineStatusToUsers::V20261019130000 < Avram::Migrator::Migration::V1
  def migrate : Nil
    alter table_for(User) do
      add hide_online_status : Bool, default: false
    end
  end

  def rollback : Nil
    alter table_for(User) do
      remove :hide_online_status
    end
  end
end
