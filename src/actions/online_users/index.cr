class OnlineUsers::Index < BrowserAction
  get "/online_users" do
    # 在线缓存可能稍有滞后，名单仍以数据库中的隐身设置为准。
    users = UserQuery.new
      .id.in(ONLINE_PRESENCE.user_ids)
      .hide_online_status(false)
      .login_name_lower.asc_order
      .results

    component(
      ::OnlineUsers::List,
      users: users,
    )
  end
end
