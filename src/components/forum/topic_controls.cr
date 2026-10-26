class Forum::TopicControls < BaseComponent
  needs topic : Topic
  needs can_delete_topic : Bool

  def render : Nil
    div id: "topic-#{topic.id}-controls", class: "flex items-center gap-1" do
      if (me = current_user)
        if me.id == topic.user_id || me.admin?
          link(
            to: Forum::Edit.with(id: topic.id),
            title: r("common.edit").t,
            class: "icon-action-button"
          ) do
            img(
              src: asset("svgs/notifications/edit.svg"),
              alt: r("common.edit").t,
              class: "icon-action-image"
            )
          end
        end

        if can_delete_topic?
          button(
            type: "button",
            title: r("common.delete").t,
            class: "icon-action-button icon-action-danger",
            hx_delete: Forum::Delete.with(id: topic.id).path,
            hx_confirm: r("forum.show_page.confirm_delete").t,
            hx_disable: "this"
          ) do
            img(
              src: asset("svgs/notifications/delete.svg"),
              alt: r("common.delete").t,
              class: "icon-action-image"
            )
          end
        end
      end
    end
  end
end
