class CreateNotifications::V20261004120000 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(Notification) do
      primary_key id : Int64
      # 收件人和触发通知的用户；不能使用客户端提供的收件人列表。
      add_belongs_to user : User, on_delete: :cascade
      add_belongs_to actor : User, on_delete: :cascade
      # 回复通知指向 Comment；提及通知可以指向 Comment 或 Topic。
      add_belongs_to comment : Comment?, on_delete: :cascade
      add_belongs_to topic : Topic?, on_delete: :cascade
      add kind : String
      # NULL 表示未读；只点击单条通知或显式全部已读时更新。
      add read_at : Time?
      add_timestamps
    end

    require_nullability_relation(:exactly_one_non_null, "notifications", "comment_id", "topic_id")
    create_index table_for(Notification), [:user_id, :comment_id], unique: true
    create_index table_for(Notification), [:user_id, :topic_id], unique: true
    create_index table_for(Notification), [:user_id, :id]
    execute "CREATE INDEX notifications_unread_user_index ON notifications (user_id) WHERE read_at IS NULL"
  end

  def rollback
    drop table_for(Notification)
  end
end
