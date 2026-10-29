abstract class CommentAction < BrowserAction
  PER_PAGE = 10

  include Lucky::Paginator::BackendHelpers
  include Auth::AllowGuests
  include MarkdownFormatter

  def comment_available?(comment : Comment) : Bool
    CommentQuery.new.id(comment.id).publicly_visible_comments.any?
  end

  # 删除或回复子评论时，先锁根评论，再锁这条子评论。
  # 删除或回复根评论时，只锁这条根评论。
  private def lock_comment(comment : Comment) : Comment
    root = CommentQuery.new.id(comment.root_id || comment.id).for_update.first

    return root if comment.root_id.nil?

    CommentQuery.new.id(comment.id).for_update.first
  end

  def comments_pagination(
    comment_thread_id : Int64? = nil,
    root_id : Int64? = nil,
    order_by : String = "desc",
  ) : NamedTuple(
    count: Int32 | Int64,
    comments: Avram::Queryable(Comment),
    page: Lucky::Paginator?,
    url: String,
    order_by: String,
  )
    return {count: 0, comments: CommentQuery.new.none, page: nil, url: "", order_by: "desc"} unless order_by.in?("desc", "asc")

    raise ArgumentError.new("comment_thread_id 和 root_id 必须且只能提供一个") if comment_thread_id.nil? == root_id.nil?

    if comment_thread_id
      q = CommentQuery.new.comment_thread_id(comment_thread_id).parent_id.is_nil
      url = "/htmx/comments?comment_thread_id=#{comment_thread_id}"
      item_count = CommentThreadQuery.find(comment_thread_id).root_comments_count
    else
      root_id = root_id.not_nil!
      q = CommentQuery.new.root_id(root_id)
      url = "/htmx/comments?root_id=#{root_id}"
      item_count = CommentQuery.find(root_id).descendants_count
    end

    q = order_by == "desc" ? q.floor.desc_order : q.floor.asc_order
    q = q.preload_user
    q = q.preload_parent &.preload_user

    if (me = current_user)
      q = q.preload_votes &.user_id(me.id)
    end

    # Avram 的 paginate 总会执行 COUNT；这里复用数据库 trigger 维护的计数。
    page = Lucky::Paginator.new(
      page: paginator_page,
      per_page: PER_PAGE,
      item_count: item_count,
      full_path: context.request.resource
    )
    comments = q.limit(page.per_page).offset(page.offset)

    {
      count:    page.item_count,
      comments: comments,
      page:     page,
      url:      url,
      order_by: order_by,
    }
  end
end
