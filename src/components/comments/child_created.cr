class Comments::ChildCreated < BaseComponent
  needs formatter : Tartrazine::Formatter
  needs pagination : Comments::Pagination
  needs comment_id : Int64
  needs root_comment : Comment

  def render : Nil
    mount(
      Comments::Replies,
      formatter: formatter,
      root_comment: root_comment,
      order_by: pagination[:order_by],
      pagination: pagination,
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
      )
    end
  end
end
