class CreateTopicActivityTrigger::V20261002120200 < Avram::Migrator::Migration::V1
  def migrate
    # 从发生变更的评论找到所属主题，再调用上一条 migration 创建的统计函数。
    create_function "refresh_comment_topic_activity", <<-SQL
      DECLARE
        thread_id bigint;
        target_topic_id bigint;
      BEGIN
        IF TG_OP = 'DELETE' THEN
          thread_id := OLD.comment_thread_id;
        ELSE
          IF TG_OP = 'UPDATE' AND OLD.soft_deleted_at IS NOT DISTINCT FROM NEW.soft_deleted_at THEN
            RETURN NULL;
          END IF;
          thread_id := NEW.comment_thread_id;
        END IF;

        SELECT topic_id INTO target_topic_id FROM comment_threads WHERE id = thread_id;
        IF target_topic_id IS NOT NULL THEN
          PERFORM refresh_topic_activity(target_topic_id);
        END IF;
        RETURN NULL;
      END;
      SQL

    # 兼容已经执行过拆分前 migration 的数据库，替换旧 trigger。
    drop_trigger table_for(Comment), "refresh_topic_activity_after_comment_change"

    # 只在新增、物理删除、软删除或恢复时重算；编辑正文、投票不触发。
    execute <<-SQL
      CREATE TRIGGER refresh_topic_activity_after_comment_change
      AFTER INSERT OR DELETE OR UPDATE OF soft_deleted_at ON comments
      FOR EACH ROW EXECUTE FUNCTION refresh_comment_topic_activity();
      SQL
  end

  def rollback
    drop_trigger table_for(Comment), "refresh_topic_activity_after_comment_change"
    drop_function "refresh_comment_topic_activity"
  end
end
