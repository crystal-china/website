class Comments::Deleted < BaseComponent
  needs formatter : Tartrazine::Formatter
  needs pagination : Comments::Pagination
  needs root_comment : Comment?

  def render : Nil
    root = root_comment
    html_id = root ? "comment-#{root.id}-comments" : "comments"

    if root.nil? || pagination[:count] > 0
      mount(
        Comments::List,
        formatter: formatter,
        pagination: pagination,
        current_user: current_user,
        comment_id: nil,
        html_id: html_id
      )
    else
      div id: html_id
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

      tag(
        "hx-partial",
        hx_target: "#comment-#{root.id}-thread-toggle",
        hx_swap: "outerHTML swap:1s"
      ) do
        mount(
          Comments::ThreadToggle,
          comment: root,
          order_by: pagination[:order_by],
          expanded: pagination[:count] > 0,
          current_user: current_user
        )
      end
    end
  end
end
