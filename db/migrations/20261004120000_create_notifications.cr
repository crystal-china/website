class CreateNotifications::V20261004120000 < Avram::Migrator::Migration::V1
  def migrate : Nil
    create table_for(Notification) do
      primary_key id : Int64
      # 收件人和触发通知的用户；不能使用客户端提供的收件人列表。
      add_belongs_to user : User, on_delete: :cascade, index: false # 这条通知属于谁；下方复合索引已覆盖 user_id。
      add_belongs_to actor : User, on_delete: :cascade              # 执行动作的人，动作包括，回复、提及、点赞、关注等
      # 站内目标地址；评论使用 /comments/:id，点击时再计算所在分页。
      # 不关联目标记录，目标被删除后仍保留这条历史通知。
      add url : String
      # 存储 Notification::Kind 的固定整数值；以后新增类型不要改变已有值。
      add kind : Int32
      # 创建时的标题快照，不随标题编辑或目标软删除而改变。
      add source_title : String
      # 原始正文前 120 个字符，页面按纯文本输出，不保存渲染后的 HTML。
      add excerpt : String
      # NULL 表示未读；只点击单条通知或显式全部已读时更新。
      add read_at : Time?
      add_timestamps
    end

    # 加速代码中的回复/提及去重查询，不限制管理操作的重复通知。
    create_index table_for(Notification), [:user_id, :url, :kind]
    create_index table_for(Notification), [:user_id, :id]
    execute "CREATE INDEX notifications_unread_user_index ON notifications (user_id) WHERE read_at IS NULL"
  end

  def rollback : Nil
    drop table_for(Notification)
  end
end
