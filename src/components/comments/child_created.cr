class Comments::ChildCreated < BaseComponent
  needs formatter : Tartrazine::Formatter
  needs pagination : Comments::Pagination
  needs comment_id : Int64
  needs root_comment : Comment

  def render : Nil
    mount(
      Comments::Thread,
      formatter: formatter,
      root_comment: root_comment,
      order_by: pagination[:order_by],
      pagination: pagination,
      current_user: current_user,
      comment_id: comment_id
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
        current_user: current_user
      )
    end
  end
end
