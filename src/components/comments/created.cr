class Comments::Created < BaseComponent
  needs formatter : Tartrazine::Formatter
  needs pagination : Comments::Pagination
  needs comment_id : Int64
  needs topic : Topic?

  def render : Nil
    mount(
      Comments::List,
      formatter: formatter,
      pagination: pagination,
      comment_id: comment_id,
      html_id: "comments"
    )

    if (topic = self.topic) && (me = current_user)
      if me.id == topic.user_id || me.admin?
        # 已有评论，作者不能再删除主题；管理员仍可删除。
        tag(
          "hx-partial",
          hx_target: "#topic-#{topic.id}-controls",
          hx_swap: "outerHTML"
        ) do
          mount(
            Forum::TopicControls,
            topic: topic,
            can_delete_topic: me.admin?
          )
        end
      end
    end
  end
end
