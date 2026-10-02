class Htmx::Comments::Delete < CommentAction
  param order_by : String = "desc"

  delete "/htmx/comments/:id" do
    me = current_user
    return head 401 if me.nil?

    status = 200
    deleted_comment : Comment? = nil

    AppDatabase.transaction do
      comment = CommentQuery.new.id(id).for_update.first
      next status = 404 unless comment_available?(comment)
      next status = 403 unless comment.user_id == me.id || me.admin?
      # 软删除不会移除子评论记录；作者只要有直接回复，就不能删除。
      next status = 409 if !me.admin? && CommentQuery.new.with_soft_deleted.parent_id(comment.id).any?

      DeleteComment.delete!(comment)
      deleted_comment = comment
    end

    return head status unless status == 200

    comment = deleted_comment.not_nil!

    # 删除后原来的分页位置可能移动，单纯从页面移除卡片会造成下一页漏项。
    root_comment : Comment? = nil

    if (root_id = comment.root_id)
      pagination = comments_pagination(root_id: root_id, order_by: order_by)
      root_comment = CommentQuery.find(root_id)
    else
      pagination = comments_pagination(comment_thread_id: comment.comment_thread_id, order_by: order_by)
    end

    component(
      ::Comments::Deleted,
      formatter: formatter,
      pagination: pagination,
      root_comment: root_comment,
      current_user: me
    )
  end
end
