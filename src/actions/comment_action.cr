abstract class CommentAction < BrowserAction
  include Lucky::Paginator::BackendHelpers
  include Auth::AllowGuests
  include MarkdownFormatter

  def comments_pagination(comment_thread_id : Int64? = nil, root_id : Int64? = nil, order_by : String = "desc", per_page : Int32 = 10)
    return {count: 0, comments: CommentQuery.new.none, page: nil, url: "", order_by: "desc"} unless order_by.in?("desc", "asc")

    raise ArgumentError.new("comment_thread_id 和 root_id 必须且只能提供一个") if comment_thread_id.nil? == root_id.nil?

    if comment_thread_id
      q = CommentQuery.new.comment_thread_id(comment_thread_id).parent_id.is_nil
      url = "/htmx/comments?comment_thread_id=#{comment_thread_id}"
    else
      root_id = root_id.not_nil!
      q = CommentQuery.new.root_id(root_id)
      url = "/htmx/comments?root_id=#{root_id}"
    end

    q = order_by == "desc" ? q.id.desc_order : q.id.asc_order
    q = q.preload_user
    q = q.preload_parent { |parent_query| parent_query.preload_user }

    if (me = current_user)
      q = q.preload_votes { |vote_query| vote_query.user_id(me.id) }
    end

    page, comments = paginate(q, per_page: per_page)

    {
      count:    page.item_count,
      comments: comments,
      page:     page,
      url:      url,
      order_by: order_by,
    }
  end
end
