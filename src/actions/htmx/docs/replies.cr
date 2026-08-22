class Htmx::Docs::Replies < DocAction
  param order_by : String = "desc"

  get "/htmx/replies/*:id_or_doc_path" do
    page_number = params.get?(:page).try &.to_i

    return head 401 if id_or_doc_path.nil?

    # doc_path 示例：docs/index，完整: /htmx/replies/docs/index
    id_or_doc_path = self.id_or_doc_path.not_nil!

    pagination = replies_pagination(id_or_doc_path: id_or_doc_path, order_by: order_by)

    id = id_or_doc_path.to_i64?

    if page_number && page_number > 1
      component(
        ::Docs::RepliesMore,
        formatter: formatter,
        pagination: pagination,
        page_number: page_number,
        current_user: current_user,
        reply_id: id
      )
    else
      html_id = if id
                  "doc_reply-#{id}-replies"
                else
                  "replies"
                end

      component(
        ::Docs::Replies,
        formatter: formatter,
        pagination: pagination,
        current_user: current_user,
        reply_id: id,
        html_id: html_id
      )
    end
  end
end
