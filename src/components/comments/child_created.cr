class Comments::ChildCreated < BaseComponent
  needs formatter : Tartrazine::Formatter
  needs pagination : Comments::Pagination
  needs comment_id : Int64
  needs root_comment : Comment

  def render : Nil
    mount(
      Comments::List,
      formatter: formatter,
      pagination: pagination,
      current_user: current_user,
      comment_id: comment_id,
      html_id: "comment-#{root_comment.id}-comments"
    )

    tag(
      "hx-partial",
      hx_target: "#comment-#{root_comment.id}-controls",
      hx_swap: "outerHTML"
    ) do
      mount(
        Comments::CardControls,
        comment: root_comment,
        order_by: pagination[:order_by],
        reply_expanded: true,
        current_user: current_user
      )
    end
  end
end
