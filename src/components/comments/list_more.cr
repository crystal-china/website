class Comments::ListMore < BaseComponent
  needs formatter : Tartrazine::Formatter
  needs pagination : Comments::Pagination
  needs page_number : Int32
  needs comment_id : Int64?
  needs focused_comment : Comment? = nil

  def render : Nil
    focus = focused_comment

    pagination[:comments].results.each do |comment|
      reply_expanded = false
      focus_id : Int64? = nil

      if focus
        # **当前卡片是不是目标评论所属的根评论？**如果是，就自动展开它，才能找到目标子评论。
        if focus.root_id == comment.id
          reply_expanded = true
          focus_id = focus.id
        elsif focus.id == comment.id
          focus_id = focus.id
        end
      end

      mount(
        Comments::Card,
        formatter: formatter,
        comment: comment,
        order_by: pagination[:order_by],
        show_update_success: comment_id == comment.id,
        current_user: current_user,
        reply_expanded: reply_expanded,
        focused_comment_id: focus_id
      )
    end

    mount(
      Comments::LoadMoreButton,
      pagination: pagination,
      page_number: page_number,
    )
  end
end
