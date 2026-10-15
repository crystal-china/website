class AddLoginNameLowerToUsers::V20261011120050 < Avram::Migrator::Migration::V1
  def migrate : Nil
    # Store the normalized identity once on each write. PostgreSQL maintains it
    # for every INSERT/UPDATE, including direct SQL; clients cannot overwrite it.
    execute <<-SQL
      ALTER TABLE users
      ADD login_name_lower text GENERATED ALWAYS AS (lower(login_name)) STORED NOT NULL
      SQL

    execute <<-SQL
      CREATE INDEX users_login_name_lower_prefix_index
      ON users (login_name_lower text_pattern_ops)
      SQL
  end

  def rollback : Nil
    alter table_for(User) do
      remove :login_name_lower
    end
  end
end
