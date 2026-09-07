class Htmx::Comments::Index < DocAction
  param order_by : String = "desc"

  get "/htmx/comments/*:id_or_doc_path" do
    page_number = params.get?(:page).try &.to_i

    return head 401 if id_or_doc_path.nil?

    # doc_path 示例：docs/index，完整: /htmx/comments/docs/index
    id_or_doc_path = self.id_or_doc_path.not_nil!

    pagination = comments_pagination(id_or_doc_path: id_or_doc_path, order_by: order_by)

    id = id_or_doc_path.to_i64?

    if page_number && page_number > 1
      component(
        ::Comments::ListMore,
        formatter: formatter,
        pagination: pagination,
        page_number: page_number,
        current_user: current_user,
        comment_id: id
      )
    else
      html_id = if id
                  "comment-#{id}-comments"
                else
                  "comments"
                end

      component(
        ::Comments::List,
        formatter: formatter,
        pagination: pagination,
        current_user: current_user,
        comment_id: id,
        html_id: html_id
      )
    end
  end
end
