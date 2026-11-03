class AddLastReplyIdToTopics::V20261103120000 < Avram::Migrator::Migration::V1
  def migrate : Nil
    alter table_for(Topic) do
      add last_reply_id : Int64?
    end

    create_function "record_topic_reply", <<-SQL
      BEGIN
        -- 与现有主题活动信息一起更新，不增加一次评论查询或修改主题编辑时间。
        UPDATE topics AS topic
        SET replies_count = topic.replies_count + 1,
            last_reply_id = NEW.id,
            last_reply_user_id = NEW.user_id,
            last_active_at = NEW.created_at
        FROM comment_threads AS thread
        WHERE thread.id = NEW.comment_thread_id AND topic.id = thread.topic_id;

        RETURN NULL;
      END;
      SQL

    # 包含已软删除的主题；回填可见回复的最大 ID，不走 Operation 或改变编辑时间。
    execute <<-SQL
      UPDATE topics
      SET last_reply_id = (
        SELECT MAX(comments.id)
        FROM comment_threads
        JOIN comments ON comments.comment_thread_id = comment_threads.id
        WHERE comment_threads.topic_id = topics.id
          AND comments.soft_deleted_at IS NULL
      )
      SQL
  end

  def rollback : Nil
    create_function "record_topic_reply", <<-SQL
      BEGIN
        UPDATE topics AS topic
        SET replies_count = topic.replies_count + 1,
            last_reply_user_id = NEW.user_id,
            last_active_at = NEW.created_at
        FROM comment_threads AS thread
        WHERE thread.id = NEW.comment_thread_id AND topic.id = thread.topic_id;

        RETURN NULL;
      END;
      SQL

    alter table_for(Topic) do
      remove :last_reply_id
    end
  end
end
