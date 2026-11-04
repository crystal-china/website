class Htmx::Comments::Index < CommentAction
  param order_by : String = "desc"
  param comment_thread_id : Int64?
  param root_id : Int64?
  param comment_id : Int64?
  @focused_page : Int32?

  get "/htmx/comments" do
    page_number = params.get?(:page).try &.to_i
    root_comment : Comment? = nil

    return head 400 if comment_thread_id.nil? == root_id.nil?

    if (thread_id = comment_thread_id)
      return head 404 unless CommentThreadQuery.find(thread_id).target_visible?
    elsif (root_comment_id = root_id)
      root_comment = CommentQuery.find(root_comment_id)

      return head 404 unless comment_available?(root_comment)
    end

    focused_comment : Comment? = nil

    if (focus_id = comment_id)
      focused_comment = CommentQuery.find(focus_id)

      return head 404 unless comment_available?(focused_comment)
      return head 404 if comment_thread_id && focused_comment.comment_thread_id != comment_thread_id
      return head 404 if root_id && focused_comment.root_id != root_id

      # 如果是打开在 root_comment 下隐藏的子评论，请求会执行两次，两次分别进入不同的分支。
      # 第一次：anchor = 根评论100 preceding = 下面的所有顶级评论
      # 第二次：anchor = 子评论123 preceding = 根评论100下面的所有子评论
      #
      # 即：找外层的根评论，再找内层的目标子评论。如果目标本身就是根评论，只需要第一次请求
      if comment_thread_id
        anchor = focused_comment.root_id ? CommentQuery.find(focused_comment.root_id.not_nil!) : focused_comment
        preceding = CommentQuery.new.comment_thread_id(comment_thread_id.not_nil!).parent_id.is_nil
      else
        anchor = focused_comment
        preceding = CommentQuery.new.root_id(root_id.not_nil!)
      end

      preceding = order_by == "asc" ? preceding.floor.lt(anchor.floor) : preceding.floor.gt(anchor.floor)
      @focused_page = (preceding.select_count // App::SMALL_PER_PAGE + 1).to_i
      page_number = @focused_page
    end

    pagination = comments_pagination(
      comment_thread_id: comment_thread_id,
      root_id: root_id,
      order_by: order_by
    )

    if focused_comment.nil?
      if page_number && page_number > 1
        # 加载更多：返回 ListMore，追加下一页评论，例如：?root_id=100&page=2
        component(
          ::Comments::ListMore,
          formatter: formatter,
          pagination: pagination,
          page_number: page_number,
          comment_id: root_id
        )
      elsif root_comment
        # 展开、排序子回复：返回 Replies，替换标题栏和子列表。例如：?root_id=100&order_by=asc
        component(
          ::Comments::Replies,
          formatter: formatter,
          root_comment: root_comment,
          order_by: pagination[:order_by],
          pagination: pagination
        )
      else
        # 普通主评论区首次加载、切换排序, ?comment_thread_id=10
        render_comment_list(pagination, nil)
      end
    else
      # 通知定位，可以是主评论区定位，也可以是子回复区定位
      # - 定位所属根评论 ?comment_thread_id=10&comment_id=113
      # - 定位具体子评论 ?root_id=100&comment_id=113
      render_comment_list(pagination, focused_comment)
    end
  end

  private def render_comment_list(
    pagination : ::Comments::Pagination,
    focused_comment : Comment?,
  ) : Lucky::TextResponse
    html_id = root_id ? "comment-#{root_id}-replies-list" : "comments"

    component(
      ::Comments::List,
      formatter: formatter,
      pagination: pagination,
      comment_id: root_id,
      html_id: html_id,
      focused_comment: focused_comment,
      show_toolbar: root_id.nil?
    )
  end

  def paginator_page : Int32
    @focused_page || super
  end
end
