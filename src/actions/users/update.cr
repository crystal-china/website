class Users::Update < BrowserAction
  put "/users/:id" do
    user = UserQuery.find(id)
    me = current_user

    return head 404 unless me.id == user.id || me.admin?

    UpdateUser.update(
      user,
      params,
      actor_id: me.id
    ) do |op, updated_user|
      if op.saved?
        updated_user = updated_user.not_nil!
        sign_in(updated_user) if me.id == user.id
        flash.success = r(".profile_updated").t

        redirect Users::Show.with(login_name: updated_user.login_name)
      else
        password_changed_at = UserAuditQuery.new.user_id(user.id).latest_password_change_at

        build_failed_flash(op)

        html(
          Users::EditPage,
          user: user,
          op: op,
          password_changed_at: password_changed_at
        )
      end
    end
  end
end
