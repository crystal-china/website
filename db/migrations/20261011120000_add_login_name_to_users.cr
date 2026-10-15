class AddLoginNameToUsers::V20261011120000 < Avram::Migrator::Migration::V1
  def migrate : Nil
    alter table_for(User) do
      # Preserve the user's spelling; login_name_lower will handle identity lookup.
      add login_name : String?
    end

    # Preserve existing @mentions by copying the renamed nickname verbatim.
    execute "UPDATE users SET login_name = nickname"

    make_required table_for(User), :login_name
  end

  def rollback : Nil
    alter table_for(User) do
      remove :login_name
    end
  end
end
