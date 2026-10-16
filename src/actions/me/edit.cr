class Me::Edit < BrowserAction
  get "/me/edit" do
    password_change = UserAuditQuery.new.user_id(current_user.id).latest_password_change

    html Me::EditPage, op: UpdateUser.new(current_user), password_changed_at: password_change.try(&.created_at)
  end
end
