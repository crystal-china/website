class AddTopicActivity::V20261002120000 < Avram::Migrator::Migration::V1
  def migrate
    alter table_for(Topic) do
      # 当前可见回复总数，包含子评论；根评论已删除的整个分支不参与统计。
      # record_topic_reply AFTER INSERT trigger 在新增时递增；软删除和恢复由 callback 重算。
      add replies_count : Int32, default: 0

      # 最后一条可见回复的作者；没有可见回复时为空，不复制可能变更的用户名。
      add_belongs_to last_reply_user : User?, on_delete: :nullify

      # 新主题默认当前时间；有回复后使用最后一条可见回复的创建时间。
      # 删除、恢复回复及回填时重新计算，没有可见回复时回到主题创建时间。
      # 编辑正文不更新此值。
      # 列表按此字段排序，而不是按 updated_at 排序。
      add last_active_at : Time, default: :now
    end

    create_index table_for(Topic), [:last_active_at, :id]
    create_index table_for(Topic), [:node_id, :last_active_at, :id]

    create_function "record_topic_reply", <<-SQL
      BEGIN
        -- 原子递增，并直接记录本次新增回复的作者和时间；不修改主题 updated_at。
        UPDATE topics AS topic
        SET replies_count = topic.replies_count + 1,
            last_reply_user_id = NEW.user_id,
            last_active_at = NEW.created_at
        FROM comment_threads AS thread
        WHERE thread.id = NEW.comment_thread_id AND topic.id = thread.topic_id;

        RETURN NULL;
      END;
      SQL

    create_trigger(
      table_for(Comment),
      "record_topic_reply_after_insert",
      "record_topic_reply",
      callback: :after,
      on: [:insert]
    )
  end

  def rollback
    drop_trigger table_for(Comment), "record_topic_reply_after_insert"
    drop_function "record_topic_reply"

    drop_index table_for(Topic), [:node_id, :last_active_at, :id]
    drop_index table_for(Topic), [:last_active_at, :id]

    alter table_for(Topic) do
      remove_belongs_to :last_reply_user
      remove :last_active_at
      remove :replies_count
    end
  end
end
