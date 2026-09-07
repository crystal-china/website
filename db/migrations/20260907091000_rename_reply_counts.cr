class RenameReplyCounts::V20260907091000 < Avram::Migrator::Migration::V1
  def migrate
    alter :replies do
      rename :direct_replies_count, :children_count
      rename :thread_replies_count, :descendants_count
    end
  end

  def rollback
    alter :replies do
      rename :children_count, :direct_replies_count
      rename :descendants_count, :thread_replies_count
    end
  end
end
