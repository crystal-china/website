class Shared::OnlineUsers < BaseComponent
  needs user_count : Int32
  needs guest_count : Int32

  def render : Nil
    text "在线用户 #{user_count} 人, 游客 #{guest_count} 人"

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
