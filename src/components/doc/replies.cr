class Docs::Replies < BaseComponent
  needs formatter : Tartrazine::Formatter
  needs pagination : {count: Int32 | Int64, replies: ReplyQuery, page: Lucky::Paginator?, url: String}
  needs order_by : String
  needs html_id : String
  needs reply_id : Int64?

  def render
    div role: "feed", id: html_id do
      mount(
        ::Docs::FormButtons,
        page_count: pagination[:count],
        reply_path: pagination[:url],
        order_by: order_by,
        hx_target: "div##{html_id}"
      )

      mount(
        ::Docs::RepliesMore,
        formatter: formatter,
        pagination: pagination,
        page_number: 1,
        current_user: current_user,
        reply_id: reply_id
      )
    end
  end
end
