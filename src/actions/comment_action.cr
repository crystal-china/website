abstract class CommentAction < BrowserAction
  include Lucky::Paginator::BackendHelpers
  include Auth::AllowGuests
  include MarkdownFormatter

  def comment_available?(comment : Comment) : Bool
    # 先检查，评论所属主题是否可见？（即：如果主题被软删除，那么它级联的记录全部不可访问）
    return false unless CommentThreadQuery.find(comment.comment_thread_id).target_visible?

    # 如果上一条没问题，那么它的顶级评论默认可见。
    # 除非它是一个子评论，此时进入下一轮判断。
    return true unless (root_id = comment.root_id)

    # 如果是子评论，要判断它 root 评论是否可见。
    CommentQuery.new.id(root_id).any?
  end

  def comments_pagination(comment_thread_id : Int64? = nil, root_id : Int64? = nil, order_by : String = "desc", per_page : Int32 = 10) : NamedTuple(
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
    else
      root_id = root_id.not_nil!
      q = CommentQuery.new.root_id(root_id)
      url = "/htmx/comments?root_id=#{root_id}"
    end

    q = order_by == "desc" ? q.floor.desc_order : q.floor.asc_order
    q = q.preload_user
    q = q.preload_parent &.preload_user

    if (me = current_user)
      q = q.preload_votes &.user_id(me.id)
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
