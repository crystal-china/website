class Admin::Users::RemovePassword < AdminAction
  post "/admin/users/:id/remove_password" do
    user = UserQuery.find(id)

    if user.encrypted_password.nil?
      flash.info = "此账号没有本站密码，无需移除。"

      return redirect Admin::Users::Edit.with(id: user.id)
    end

    updated_user = RemoveUserPassword.update!(user, actor_id: current_user.id)

    sign_in(updated_user) if current_user.id == user.id
    flash.success = "本站密码已移除，旧登录会话已失效。用户可通过第三方登录或重置密码重新登录。"

    redirect Admin::Users::Edit.with(id: user.id)
  end
end
