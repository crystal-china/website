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
      q = ReplyQuery.new.doc_id(current_doc.id)
    else
      root_reply = thread_root_reply(ReplyQuery.find(id))
      reply_ids = thread_reply_ids(root_reply.id)
      q = reply_ids.empty? ? ReplyQuery.new.none : ReplyQuery.new.id.in(reply_ids)
      url = "/htmx/replies/#{root_reply.id}"
    end

    q = order_by == "desc" ? q.id.desc_order : q.id.asc_order

    page, replies = paginate(q, per_page: per_page)

    {
      count:   page.item_count,
      replies: replies,
      page:    page,
      url:     url,
      order_by: order_by,
    }
  end

  # 第一条针对评论的评论
  protected def thread_root_reply(reply : Reply) : Reply
    current = reply

    while (parent_id = current.reply_id)
      current = ReplyQuery.find(parent_id)
    end

    current
  end

  private def thread_reply_ids(root_reply_id : Int64) : Array(Int64)
    reply_ids = [] of Int64
    frontier = [root_reply_id]

    until frontier.empty?
      children = ReplyQuery.new.reply_id.in(frontier).results
      break if children.empty?

      child_ids = children.map(&.id)
      reply_ids.concat(child_ids)
      frontier = child_ids
    end

    reply_ids
  end

  memoize def formatter : Tartrazine::Formatter
    Tartrazine::Html.new(
      theme: Tartrazine.theme("catppuccin-macchiato"),
      line_numbers: true,
      standalone: false,
    )
  end
end
