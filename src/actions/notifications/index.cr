class Notifications::Index < BrowserAction
  include NotificationHelpers

  param only_show_unread : Bool? = nil

  get "/notifications" do
    session.set(:notifications_unread, only_show_unread.to_s) unless only_show_unread.nil?

    render_notifications
  end
end
