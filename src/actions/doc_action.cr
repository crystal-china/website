abstract class DocAction < BrowserAction
  include Lucky::Paginator::BackendHelpers
  include Auth::AllowGuests
  include PageHelpers

  expose formatter

  def replies_pagination(id_or_doc_path : String, order_by : String = "desc", per_page : Int32 = 10)
    return {count: 0, replies: ReplyQuery.new.none, page: nil, url: "", order_by: "desc"} unless order_by.in?("desc", "asc")

    id = id_or_doc_path.to_i64?

    if id.nil?
      doc_path = id_or_doc_path.starts_with?("/") ? id_or_doc_path : "/#{id_or_doc_path}"
      url = doc_path.sub("/docs", "/htmx/replies/docs")
      current_doc = DocQuery.new.path_index(doc_path).first
      q = ReplyQuery.new.doc_id(current_doc.id).reply_id.is_nil
    else
      reply = ReplyQuery.find(id)
      # 顶级评论的 root_reply_id 为 nil，它自己就是线程根；子评论则直接使用已保存的线程根 ID。
      root_reply_id = reply.root_reply_id || reply.id
      q = ReplyQuery.new.root_reply_id(root_reply_id)
      url = "/htmx/replies/#{root_reply_id}"
    end

    q = order_by == "desc" ? q.id.desc_order : q.id.asc_order

    page, replies = paginate(q, per_page: per_page)

    {
      count:    page.item_count,
      replies:  replies,
      page:     page,
      url:      url,
      order_by: order_by,
    }
  end

  memoize def formatter : Tartrazine::Formatter
    Tartrazine::Html.new(
      theme: Tartrazine.theme("catppuccin-macchiato"),
      line_numbers: true,
      standalone: false,
    )
  end
end
