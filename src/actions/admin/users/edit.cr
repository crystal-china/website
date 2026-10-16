class Admin::Users::Edit < AdminAction
  get "/admin/users/:id/edit" do
    user = UserQuery.find(id)
    password_change = UserAuditQuery.new.user_id(user.id).latest_password_change

    html Admin::Users::EditPage, user: user, op: UpdateUser.new(user), password_changed_at: password_change.try(&.created_at)
  end
end
