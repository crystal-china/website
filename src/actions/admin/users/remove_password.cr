class Admin::Users::RemovePassword < AdminAction
  delete "/admin/users/:id/remove_password" do
    user = UserQuery.find(id)

    if user.encrypted_password.nil?
      flash.info = r(".no_password").t

      return component Shared::FlashMessages, flash: flash
    end

    updated_user = RemoveUserPassword.update!(user, actor_id: current_user.id)

    sign_in(updated_user) if current_user.id == user.id
    flash.success = r(".password_removed").t

    component Shared::FlashMessages, flash: flash
  end
end
