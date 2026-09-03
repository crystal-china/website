class RemoveReplyProfileCache::V20260903090000 < Avram::Migrator::Migration::V1
  def migrate
    alter :replies do
      remove :user_name
      remove :user_avatar
    end
  end

  def rollback
    alter :replies do
      add user_name : String, default: ""
      add user_avatar : String?
    end
  end
end
