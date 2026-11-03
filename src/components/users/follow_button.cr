class Users::FollowButton < BaseComponent
  needs user : User
  needs followed : Bool

  def render : Nil
    me = current_user

    return if me.nil? || me.id == user.id

    options = if followed?
                {hx_delete: Users::Follows::Delete.with(user_id: user.id).path}
              else
                {hx_post: Users::Follows::Create.with(user_id: user.id).path}
              end

    button(
      followed? ? r(".unfollow").t : r(".follow").t,
      options,
      type: "button",
      class: "form-secondary #{followed? ? "border-sky-300 bg-sky-50 text-sky-800 hover:border-sky-400 hover:bg-sky-100" : ""}",
      title: followed? ? r(".unfollow_help").t : r(".follow_help").t,
      hx_target: "this",
      hx_swap: "outerHTML",
      hx_push_url: "false",
      hx_disable: "this"
    )
  end
end
