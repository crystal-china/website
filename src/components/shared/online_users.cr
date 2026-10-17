class Shared::OnlineUsers < BaseComponent
  needs user_count : Int32
  needs guest_count : Int32

  def render : Nil
    text r(".online").t(users: user_count.to_s, guests: guest_count.to_s)

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
