class Htmx::OnlineUsers < BrowserAction
  include Auth::AllowGuests

  patch "/htmx/online_users" do
    if (me = current_user)
      COUNTER_MUTEX.synchronize do
        ONLINE_USER_COUNTER.write(me.id.to_s, Time.local.to_unix)
      end
    else
      ONLINE_IP_COUNTER.write(context.request.remote_ip || "0.0.0.0", "")
    end

    plain_text "在线用户 #{ONLINE_USER_COUNTER.keys.size} 人, 游客 #{ONLINE_IP_COUNTER.keys.size} 人"
  end
end
