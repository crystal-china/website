# 为一条已有评论新建子评论。这里的 comment 是“被回复的那条旧评论”。
# 回复顶级评论时，它自己就是线程根；回复子评论时，继承该子评论所属的线程根。
# 成功后刷新所属根评论的子回复区和操作按钮。
class Htmx::Comments::ReplyToComment < CommentAction
  param content : String = ""
  param order_by : String = "desc"

  post "/htmx/comments/:id/replies" do
    me = current_user

    return head 401 if me.nil?
    return head 400 if content.blank?

    comment = CommentQuery.find(id)
    root_id = comment.root_id || comment.id
    reply = CreateCommentReply.run(
      parent: comment,
      user_id: me.id,
      content: content
    ) do |operation, reply|
      if (reason = operation.rejection_reason)
        return head 404 if reason.target_unavailable?
      end

      return head 500 if reply.nil?

      reply
    end

    pagination = comments_pagination(root_id: root_id, order_by: order_by)
    root_comment = CommentQuery.find(root_id)

    context.response.headers["X-Draft-Saved"] = "true"

    component(
      ::Comments::ChildCreated,
      formatter: formatter,
      pagination: pagination,
      comment_id: reply.id,
      root_comment: root_comment
    )
  end
end
