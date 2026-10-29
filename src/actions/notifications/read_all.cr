class Notifications::ReadAll < BrowserAction
  include NotificationHelpers

  post "/notifications/read_all" do
    NotificationQuery.new.user_id(current_user.id).read_at.is_nil.update(read_at: Time.utc)

    # trigger 已更新数据库；当前请求缓存的用户对象仍是操作前的计数。
    render_notifications(current_user.reload)
  end
end
