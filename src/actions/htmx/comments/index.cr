class Htmx::Comments::Index < CommentAction
  param order_by : String = "desc"
  param comment_thread_id : Int64?
  param root_id : Int64?

  get "/htmx/comments" do
    page_number = params.get?(:page).try &.to_i

    return head 400 if comment_thread_id.nil? == root_id.nil?

    pagination = comments_pagination(
      comment_thread_id: comment_thread_id,
      root_id: root_id,
      order_by: order_by
    )

    if page_number && page_number > 1
      component(
        ::Comments::ListMore,
        formatter: formatter,
        pagination: pagination,
        page_number: page_number,
        current_user: current_user,
        comment_id: root_id
      )
    else
      html_id = if root_id
                  "comment-#{root_id}-comments"
                else
                  "comments"
                end

      component(
        ::Comments::List,
        formatter: formatter,
        pagination: pagination,
        current_user: current_user,
        comment_id: root_id,
        html_id: html_id
      )
    end
  end
end
