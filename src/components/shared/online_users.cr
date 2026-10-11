class Shared::OnlineUsers < BaseComponent
  needs user_count : Int32
  needs guest_count : Int32

  def render
    text "在线用户 #{user_count} 人, 游客 #{guest_count} 人"

    return if current_user.nil?

    # 请求路径是心跳接口，铃铛高亮应按浏览器所在页面判断。
    path = URI.parse(context.request.headers["HX-Current-URL"]? || "/").path

    tag(
      "hx-partial",
      hx_target: "#notification-status",
      hx_swap: "outerHTML"
    ) do
      mount Navbar::NotificationLink,
        active: path.starts_with?("/notifications"),
        current_user: current_user
    end
  end
end
