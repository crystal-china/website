class Admin::Users::RemovePassword < AdminAction
  post "/admin/users/:id/remove_password" do
    user = UserQuery.find(id)

    if user.encrypted_password.nil?
      flash.info = r(".no_password").t

      return redirect Admin::Users::Edit.with(id: user.id)
    end

    updated_user = RemoveUserPassword.update!(user, actor_id: current_user.id)

    sign_in(updated_user) if current_user.id == user.id
    flash.success = r(".password_removed").t

    redirect Admin::Users::Edit.with(id: user.id)
  end
end
