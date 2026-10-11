class Navbar::NotificationLink < BaseComponent
  needs active : Bool

  def render
    user = current_user

    return if user.nil?

    unread = NotificationQuery.new.user_id(user.id).read_at.is_nil.any?
    classes = active? ? "nav-icon-link is-active" : "nav-icon-link"

    span id: "notification-status", class: "inline-flex" do
      link(
        to: Notifications::Index,
        class: classes,
        title: "通知",
        "aria-label": unread ? "通知，有未读通知" : "通知"
      ) do
        img src: asset("svgs/notification-bell.svg"), alt: "", class: "h-5 w-5"

        if unread
          span class: "absolute top-1.5 right-1.5 h-2 w-2 rounded-full bg-red-500 ring-2 ring-[#F2F4F6]", "aria-hidden": "true"
        end
      end
    end
  end
end
