class ReplaceNotificationUrlsWithTargets::V20261103130000 < Avram::Migrator::Migration::V1
  def migrate : Nil
    alter table_for(Notification) do
      # 普通 ID 字段，不关联删除目标时的级联操作。
      add topic_id : Int64?
      add comment_id : Int64?
    end

    # 兼容已有站内通知；不改已读状态、快照、时间或通知计数。
    execute <<-SQL
      UPDATE notifications
      SET topic_id = substring(url FROM '^/forum/([0-9]+)$')::bigint,
          comment_id = substring(url FROM '^/comments/([0-9]+)$')::bigint
      SQL

    execute <<-SQL
      UPDATE notifications AS notification
      SET topic_id = thread.topic_id
      FROM comments AS comment
      JOIN comment_threads AS thread ON thread.id = comment.comment_thread_id
      WHERE notification.comment_id = comment.id
      SQL

    require_nullability_relation(
      :at_least_one_non_null,
      "notifications",
      "topic_id",
      "comment_id"
    )

    drop_index table_for(Notification), [:user_id, :url, :kind]

    alter table_for(Notification) do
      remove :url
    end

    # user_id、topic_id 前缀也供主题已读同步使用；comment_id 划定回复阅读范围。
    create_index table_for(Notification), [:user_id, :topic_id, :comment_id, :kind]
    create_index(
      table_for(Notification),
      [:user_id, :comment_id, :kind],
      where_raw: "comment_id IS NOT NULL"
    )
  end

  def rollback : Nil
    alter table_for(Notification) do
      add url : String?
    end

    execute <<-SQL
      UPDATE notifications
      SET url = CASE
        WHEN comment_id IS NOT NULL THEN '/comments/' || comment_id
        ELSE '/forum/' || topic_id
      END
      SQL

    make_required table_for(Notification), :url
    drop_index table_for(Notification), [:user_id, :topic_id, :comment_id, :kind]
    drop_index table_for(Notification), [:user_id, :comment_id, :kind]
    drop_nullability_relation(
      :at_least_one_non_null,
      "notifications",
      "topic_id",
      "comment_id"
    )

    alter table_for(Notification) do
      remove :topic_id
      remove :comment_id
    end

    create_index table_for(Notification), [:user_id, :url, :kind]
  end
end
