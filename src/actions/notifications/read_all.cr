class Notifications::ReadAll < BrowserAction
  post "/notifications/read_all" do
    NotificationQuery.new.user_id(current_user.id).read_at.is_nil.update(read_at: Time.utc)
    flash.success = "通知已全部标为已读"

    redirect Notifications::Index
  end
end
