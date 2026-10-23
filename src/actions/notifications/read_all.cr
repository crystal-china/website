class Notifications::ReadAll < BrowserAction
  include NotificationHelpers

  post "/notifications/read_all" do
    NotificationQuery.new.user_id(current_user.id).read_at.is_nil.update(read_at: Time.utc)

    render_notifications
  end
end
