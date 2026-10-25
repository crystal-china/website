class Comments::Deleted < BaseComponent
  needs formatter : Tartrazine::Formatter
  needs pagination : Comments::Pagination
  needs root_comment : Comment? # 被删除评论的根评论是否存在

  def render : Nil
    root = root_comment

    if root
      mount(
        Comments::Thread,
        formatter: formatter,
        root_comment: root,
        order_by: pagination[:order_by],
        pagination: pagination,
        current_user: current_user
      )
    else
      mount(
        Comments::List,
        formatter: formatter,
        pagination: pagination,
        current_user: current_user,
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
          current_user: current_user
        )
      end
    end
  end
end
