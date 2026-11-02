class Users::Follows::Delete < BrowserAction
  delete "/users/:user_id/follow" do
    me = current_user

    return head 403 if user_id.to_i64? == me.id

    user = UserQuery.find(user_id)

    user_follow_query(user.id).delete

    component(
      Users::FollowButton,
      user: user,
      followed: false
    )
  end
end
