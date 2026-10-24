class AddWithdrawnToComments::V20261024120000 < Avram::Migrator::Migration::V1
  def migrate : Nil
    alter table_for(Comment) do
      add withdrawn : Bool, default: false
    end
  end

  def rollback : Nil
    alter table_for(Comment) do
      remove :withdrawn
    end
  end
end
