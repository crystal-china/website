class Notifications::Read < BrowserAction
  post "/notifications/:id/read" do
    notification = NotificationQuery.new.user_id(current_user.id).id(id).first

    if notification.read_at.nil?
      SaveNotification.update!(notification, read_at: Time.utc)
    end

    redirect to: notification.url
  end
end
