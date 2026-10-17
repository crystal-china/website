class Me::Update < BrowserAction
  put "/me/update" do
    me = current_user

    UpdateUser.update(me, params, actor_id: me.id) do |op, user|
      if op.saved?
        sign_in(user.not_nil!)
        flash.success = r(".updated").t
        redirect Home::Index
      else
        password_change = UserAuditQuery.new.user_id(me.id).latest_password_change

        build_failed_flash(op)

        html Me::EditPage, op: op, password_changed_at: password_change.try(&.created_at)
      end
    end
  end
end
