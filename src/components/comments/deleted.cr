class Comments::Deleted < BaseComponent
  needs formatter : Tartrazine::Formatter
  needs pagination : Comments::Pagination
  needs root_comment : Comment? # 被删除评论的根评论是否存在
  needs topic : Topic? = nil

  def render : Nil
    root = root_comment

    if root
      mount(
        Comments::Replies,
        formatter: formatter,
        root_comment: root,
        order_by: pagination[:order_by],
        pagination: pagination,
      )
    else
      mount(
        Comments::List,
        formatter: formatter,
        pagination: pagination,
        comment_id: nil,
        html_id: "comments"
      )
    end

    if root
      tag(
        "hx-partial",
        hx_target: "#comment-#{root.id}-controls",
        hx_swap: "outerHTML swap:1s"
      ) do
        mount(
          Comments::CardControls,
          comment: root,
          order_by: pagination[:order_by],
        )
      end
    end

    if (topic = self.topic) && (me = current_user)
      if me.id == topic.user_id || me.admin?
        tag(
          "hx-partial",
          hx_target: "#topic-#{topic.id}-controls",
          hx_swap: "outerHTML"
        ) do
          mount(
            Forum::TopicControls,
            topic: topic,
            can_delete_topic: me.admin? || topic.replies_count.zero?
          )
        end
      end
    end
  end
end
