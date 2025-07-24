class CreateUsers::V00000000000001 < Avram::Migrator::Migration::V1
  def migrate
    enable_extension "citext"

    create table_for(User) do
      primary_key id : Int64
      add name : String, unique: true
      add avatar : String?
      add email : String, unique: true, case_sensitive: false
      add encrypted_password : String?
      add last_active_at : Time?, index: true
      add_timestamps
    end
  end

  def rollback
    drop table_for(User)
    disable_extension "citext"
  end
end
