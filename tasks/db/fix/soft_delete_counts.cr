class Db::Fix::SoftDeleteCounts < LuckyTask::Task
  summary "Rebuild visible comment counters after enabling soft deletion (safe to rerun)"

  def call : Nil
    AppDatabase.transaction do
      AppDatabase.exec <<-SQL
        UPDATE comments AS parent
        SET children_count = (
          SELECT COUNT(*) FROM comments AS child
          WHERE child.parent_id = parent.id AND child.soft_deleted_at IS NULL
        ),
        descendants_count = (
          SELECT COUNT(*) FROM comments AS child
          WHERE child.root_id = parent.id AND child.soft_deleted_at IS NULL
        )
        SQL

      AppDatabase.exec <<-SQL
        UPDATE comment_threads AS thread
        SET root_comments_count = (
          SELECT COUNT(*) FROM comments
          WHERE comment_thread_id = thread.id
            AND parent_id IS NULL
            AND soft_deleted_at IS NULL
        )
        SQL
    end

    puts "Visible comment counters rebuilt"
  end
end
