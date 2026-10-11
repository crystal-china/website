class Htmx::OnlineUsers < BrowserAction
  include Auth::AllowGuests

  patch "/htmx/online_users" do
    user_count, guest_count = ONLINE_PRESENCE_MUTEX.synchronize do
      if (me = current_user)
        ONLINE_USERS.write(me.id.to_s, Time.local)
      else
        ONLINE_GUESTS.write(context.request.remote_ip || "0.0.0.0", true)
      end

      {ONLINE_USERS.keys.size, ONLINE_GUESTS.keys.size}
    end

    component Shared::OnlineUsers,
      user_count: user_count,
      guest_count: guest_count,
      current_user: current_user
  end
end
