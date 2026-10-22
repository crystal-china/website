class Notifications::Index < BrowserAction
  include NotificationHelpers

  param unread : Bool = false

  get "/notifications" do
    render_notifications
  end
end
