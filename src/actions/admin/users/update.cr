class Admin::Users::Update < AdminAction
  put "/admin/users/:id" do
    user = UserQuery.find(id)

    UpdateUser.update(user, params, actor_id: current_user.id) do |op, updated_user|
      if op.saved?
        sign_in(updated_user.not_nil!) if current_user.id == user.id
        flash.success = "个人资料已更新"

        redirect ::Users::Show.with(login_name: updated_user.not_nil!.login_name)
      else
        password_change = UserAuditQuery.new.user_id(user.id).latest_password_change

        build_failed_flash(op)

        html Admin::Users::EditPage, user: user, op: op, password_changed_at: password_change.try(&.created_at)
      end
    end
  end
end
