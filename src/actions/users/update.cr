class Users::Update < BrowserAction
  put "/users/:id" do
    user = UserQuery.find(id)
    me = current_user

    return head 404 unless me.id == user.id || me.admin?

    context.response.headers["HX-Push-Url"] = "false"

    UpdateUser.update(
      user,
      params,
      actor_id: me.id
    ) do |op, updated_user|
      if op.saved?
        updated_user = updated_user.not_nil!
        sign_in(updated_user) if me.id == user.id
        flash.success = r(".profile_updated").t

        user = updated_user
        op = UpdateUser.new(user)
      else
        build_failed_flash(op)
      end

      password_changed_at = UserAuditQuery.new.user_id(user.id).latest_password_change_at

      # 用户修改自己时，这里要传递修改过的 user 作为  current_user
      current_user = me.id == user.id ? user : me

      # Lucky 的 html 宏会自动补上 current_user： current_user 参数, 因此上一步要传入更新过的 current_user

      html(
        Users::EditPage,
        user: user,
        op: op,
        password_changed_at: password_changed_at
      )
    end
  end
end
