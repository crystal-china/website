class CreateReplies::V20250309142021 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(Reply) do
      primary_key id : Int64
      add_belongs_to doc : Doc?, on_delete: :cascade
      add_belongs_to user : User, on_delete: :cascade
      add_belongs_to reply : Reply?, on_delete: :cascade
      add replies_counter : Int32, default: 0
      add content : String
      add user_name : String
      add user_avatar : String?
      add preferences : JSON::Any
      add votes : JSON::Any
      add_timestamps
    end
  end

  def rollback
    drop table_for(Reply)
  end
end
