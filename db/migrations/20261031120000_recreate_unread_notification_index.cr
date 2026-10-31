class RecreateUnreadNotificationIndex::V20261031120000 < Avram::Migrator::Migration::V1
  def migrate : Nil
    # 旧库使用旧名，新库的初始 migration 已使用默认名。
    drop_index(
      table_for(Notification),
      name: "notifications_unread_user_index",
      if_exists: true
    )
    drop_index(
      table_for(Notification),
      :user_id,
      if_exists: true
    )

    create_index(
      table_for(Notification),
      :user_id,
      where_raw: "read_at IS NULL"
    )
  end

  def rollback : Nil
    drop_index table_for(Notification), :user_id

    create_index(
      table_for(Notification),
      :user_id,
      name: "notifications_unread_user_index",
      where_raw: "read_at IS NULL"
    )
  end
end
