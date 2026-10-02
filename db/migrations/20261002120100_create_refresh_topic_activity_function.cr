class CreateRefreshTopicActivityFunction::V20261002120100 < Avram::Migrator::Migration::V1
  def migrate
    # Trigger 和回填 task 共用此函数，只重算指定主题，不影响文档评论。
    create_function "refresh_topic_activity(target_topic_id bigint)", <<-SQL, returns: "void"
      BEGIN
        -- 先锁定主题，再读取评论，避免并发写入覆盖较新的统计结果。
        PERFORM 1 FROM topics WHERE id = target_topic_id FOR UPDATE;
        IF NOT FOUND THEN
          RETURN;
        END IF;

        -- ponytail: 每次写入重算一个主题；大型活跃主题出现瓶颈时再改为增量更新。
        WITH visible_comments AS MATERIALIZED (
          SELECT comments.id, comments.user_id, comments.created_at
          FROM comments
          JOIN comment_threads AS threads ON threads.id = comments.comment_thread_id
          WHERE threads.topic_id = target_topic_id
            AND comments.soft_deleted_at IS NULL
            AND (comments.root_id IS NULL OR EXISTS (
              SELECT 1 FROM comments AS roots
              WHERE roots.id = comments.root_id AND roots.soft_deleted_at IS NULL
            ))
        ), latest AS (
          SELECT user_id, created_at FROM visible_comments
          ORDER BY created_at DESC, id DESC
          LIMIT 1
        )
        UPDATE topics
        SET replies_count = (SELECT COUNT(*) FROM visible_comments),
            last_reply_user_id = (SELECT user_id FROM latest),
            last_active_at = COALESCE((SELECT created_at FROM latest), topics.created_at)
        WHERE id = target_topic_id;
      END;
      SQL
  end

  def rollback
    drop_function "refresh_topic_activity"
  end
end
