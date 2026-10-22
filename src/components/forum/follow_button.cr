class Forum::FollowButton < BaseComponent
  needs topic : Topic
  needs following : Bool

  def render : Nil
    options = if following?
                {hx_delete: Forum::Follows::Delete.with(topic_id: topic.id).path}
              else
                {hx_post: Forum::Follows::Create.with(topic_id: topic.id).path}
              end

    button(
      following? ? r(".unfollow").t : r(".follow").t,
      options,
      type: "button",
      class: "action-button #{following? ? "action-button-accent" : "action-button-neutral"} h-8",
      title: following? ? r(".unfollow_help").t : r(".follow_help").t,
      hx_target: "this",
      hx_swap: "outerHTML",
      hx_push_url: "false",
      hx_disable: "this"
    )
  end
end
