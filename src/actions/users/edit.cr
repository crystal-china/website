class Users::Edit < BrowserAction
  get "/users/:id/edit" do
    user = UserQuery.find(id)
    me = current_user

    return head 404 unless me.id == user.id || me.admin?

    password_changed_at = UserAuditQuery.new.user_id(user.id).latest_password_change_at

    html(
      Users::EditPage,
      user: user,
      op: UpdateUser.new(user),
      password_changed_at: password_changed_at
    )
  end
end
