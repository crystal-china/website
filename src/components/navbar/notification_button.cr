class Navbar::NotificationButton < BaseComponent
  def render : Nil
    user = current_user

    return if user.nil?

    unread_count = user.unread_notifications_count
    label = unread_count > 0 ? r(".unread_count").t(count: unread_count) : r("common.notifications").t
    open_notifications_dialog_on_click_script = "on click open #notifications-dialog"

    span id: "notification-status", class: "inline-flex" do
      button(
        type: "button",
        class: "nav-icon-link cursor-pointer",
        title: label,
        "aria-label": label,
        "aria-haspopup": "dialog",
        "aria-controls": "notifications-dialog",
        hx_get: Notifications::Index.path,
        hx_target: "#notifications-content",
        hx_swap: "innerHTML",
        hx_sync: "#notifications-dialog:replace",
        script: open_notifications_dialog_on_click_script
      ) do
        img(
          src: asset("svgs/notification-bell.svg"),
          alt: "",
          class: "h-5 w-5"
        )

        if unread_count > 0
          span(
            unread_count > 99 ? "99+" : unread_count.to_s,
            class: "absolute -top-1 -right-1 flex h-5 min-w-5 items-center justify-center rounded-full bg-red-600 px-1 text-[10px] leading-none font-semibold text-white tabular-nums ring-2 ring-[#F2F4F6]",
            "aria-hidden": "true"
          )
        end
      end
    end
  end
end
