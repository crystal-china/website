class Shared::OnlineUsers < BaseComponent
  needs user_count : Int32
  needs guest_count : Int32

  def render : Nil
    if current_user
      button(
        r(".users").t(count: user_count),
        type: "button",
        class: "cursor-pointer text-sky-700 underline decoration-dotted underline-offset-4 hover:text-sky-900 hover:decoration-solid",
        "aria-haspopup": "dialog",
        "aria-controls": "online-users-dialog",
        hx_get: ::OnlineUsers::Index.path,
        hx_target: "#online-users-content",
        hx_swap: "innerHTML",
        script: "on click open #online-users-dialog"
      )
    else
      text r(".users").t(count: user_count)
    end

    text r(".guests").t(count: guest_count)

    return if current_user.nil?

    tag(
      "hx-partial",
      hx_target: "#notification-status",
      hx_swap: "outerHTML"
    ) do
      mount Navbar::NotificationLink, current_user: current_user
    end
  end
end
