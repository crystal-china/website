class RequireUniqueLoginNames::V20261011120100 < Avram::Migrator::Migration::V1
  def migrate : Nil
    # Run db.fix.login_names first when upgrading an existing database.
    create_index table_for(User), :login_name_lower, unique: true
  end

  def rollback : Nil
    drop_index table_for(User), :login_name_lower
  end
end
