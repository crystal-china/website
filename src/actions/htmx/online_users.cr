class Htmx::OnlineUsers < BrowserAction
  include Auth::AllowGuests

  patch "/htmx/online_users" do
    user_count, guest_count = ONLINE_PRESENCE.record(
      current_user.try(&.id),
      context.request.remote_ip || "0.0.0.0"
    )

    component(
      Shared::OnlineUsers,
      user_count: user_count,
      guest_count: guest_count,
      current_user: current_user
    )
  end
end
