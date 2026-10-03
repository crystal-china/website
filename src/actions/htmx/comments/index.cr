class Htmx::Comments::Index < CommentAction
  param order_by : String = "desc"
  param comment_thread_id : Int64?
  param root_id : Int64?
  param comment_id : Int64?
  @focused_page : Int32?

  get "/htmx/comments" do
    page_number = params.get?(:page).try &.to_i

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

      if comment_thread_id
        anchor = focused_comment.root_id ? CommentQuery.find(focused_comment.root_id.not_nil!) : focused_comment
        preceding = CommentQuery.new.comment_thread_id(comment_thread_id.not_nil!).parent_id.is_nil
      else
        anchor = focused_comment
        preceding = CommentQuery.new.root_id(root_id.not_nil!)
      end

      preceding = order_by == "asc" ? preceding.floor.lt(anchor.floor) : preceding.floor.gt(anchor.floor)
      @focused_page = (preceding.select_count // 10 + 1).to_i
      page_number = @focused_page
    end

    pagination = comments_pagination(
      comment_thread_id: comment_thread_id,
      root_id: root_id,
      order_by: order_by
    )

    if page_number && page_number > 1 && focused_comment.nil?
      component(
        ::Comments::ListMore,
        formatter: formatter,
        pagination: pagination,
        page_number: page_number,
        current_user: current_user,
        comment_id: root_id
      )
    else
      html_id = root_id ? "comment-#{root_id}-comments" : "comments"

      component(
        ::Comments::List,
        formatter: formatter,
        pagination: pagination,
        current_user: current_user,
        comment_id: root_id,
        html_id: html_id,
        focused_comment: focused_comment
      )
    end
  end

  def paginator_page : Int32
    @focused_page || super
  end
end
