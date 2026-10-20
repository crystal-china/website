class Htmx::Users::Autocomplete < BrowserAction
  param q : String = ""

  get "/htmx/users/autocomplete" do
    prefix = q.strip
    context.response.headers["Cache-Control"] = "no-store"

    return json([] of String) if prefix.size < 2 || prefix.bytesize > 100

    query = UserQuery.new.with_login_name_prefix(prefix)
    query = query.mention_notifications_enabled(true) unless current_user.admin?
    users = query
      .order_by(:login_name_lower, :asc)
      .limit(8)
      .results
      .map { |user| {nickname: user.nickname, login_name: user.login_name} }

    json users
  end
end
