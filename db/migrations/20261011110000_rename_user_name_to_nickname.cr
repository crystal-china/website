class RenameUserNameToNickname::V20261011110000 < Avram::Migrator::Migration::V1
  def migrate : Nil
    # Nicknames are display-only: duplicates and whitespace are allowed.
    drop_index table_for(User), :name
    drop_index table_for(User), name: "users_name_prefix_index"

    alter table_for(User) do
      rename :name, :nickname
    end
  end

  def rollback : Nil
    alter table_for(User) do
      rename :nickname, :name
    end

    # This intentionally fails if users have since chosen duplicate nicknames.
    create_index table_for(User), :name, unique: true
    execute "CREATE INDEX users_name_prefix_index ON users (name text_pattern_ops)"
  end
end
