class Users::Follows::Create < BrowserAction
  post "/users/:user_id/follow" do
    me = current_user

    return head 403 if user_id.to_i64? == me.id

    user = UserQuery.find(user_id)

    SaveUserFollow.upsert!(followed_user_id: user.id, follower_id: me.id)

    component(
      Users::FollowButton,
      user: user,
      followed: true
    )
  end
end
