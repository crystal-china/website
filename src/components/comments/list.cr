class Comments::List < BaseComponent
  needs formatter : Tartrazine::Formatter
  needs pagination : {count: Int32 | Int64, comments: CommentQuery, page: Lucky::Paginator?, url: String, order_by: String}
  needs html_id : String
  needs comment_id : Int64?

  def render
    div role: "feed", id: html_id do
      input type: "hidden", id: "#{html_id}-order-by", name: "order_by", value: pagination[:order_by]

      mount(
        ::Comments::Toolbar,
        pagination: pagination,
        html_id: html_id
      )

      mount(
        ::Comments::ListMore,
        formatter: formatter,
        pagination: pagination,
        page_number: 1,
        current_user: current_user,
        comment_id: comment_id
      )
    end
  end
end
