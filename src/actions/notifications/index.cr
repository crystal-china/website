class Notifications::Index < BrowserAction
  include NotificationHelpers

  get "/notifications" do
    render_notifications
  end
end
