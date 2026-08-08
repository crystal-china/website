class AddRootReplyIdToReplies::V20260808093716 < Avram::Migrator::Migration::V1
  def migrate
    alter table_for(Reply) do
      add_belongs_to root_reply : Reply?, on_delete: :cascade
    end
  end

  def rollback
    alter table_for(Reply) do
      remove_belongs_to :root_reply
    end
  end
end
