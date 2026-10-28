class Admin::Users::RemovePassword < AdminAction
  delete "/admin/users/:id/remove_password" do
    user = UserQuery.find(id)

    updated_user = RemoveUserPassword.update!(user, actor_id: current_user.id)

    sign_in(updated_user) if current_user.id == user.id
    flash.success = r(".password_removed").t

    password_changed_at = UserAuditQuery.new.user_id(user.id).latest_password_change_at

    component(
      Admin::Users::PasswordRemoved,
      user: updated_user,
      password_changed_at: password_changed_at,
      flash: flash
    )
  end
end
