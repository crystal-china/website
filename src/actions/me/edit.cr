class Me::Edit < BrowserAction
  get "/me/edit" do
    password_changed_at = UserAuditQuery.new.user_id(current_user.id).latest_password_change_at

    html Me::EditPage, op: UpdateUser.new(current_user), password_changed_at: password_changed_at
  end
end
