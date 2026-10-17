class Admin::Users::Edit < AdminAction
  get "/admin/users/:id/edit" do
    user = UserQuery.find(id)
    password_changed_at = UserAuditQuery.new.user_id(user.id).latest_password_change_at

    html Admin::Users::EditPage, user: user, op: UpdateUser.new(user), password_changed_at: password_changed_at
  end
end
