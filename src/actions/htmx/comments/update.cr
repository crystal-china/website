# 编辑一条已有评论。这里 comment 可能是：
# - CommentThread 的顶级评论
# - 针对 comment 的子评论
# 成功后只替换该评论的正文区域。
class Htmx::Comments::Update < CommentAction
  param content : String = ""

  post "/htmx/comments/:id" do
    me = current_user

    return head 401 if me.nil?
    return head 400 if content.blank?

    comment = CommentQuery.find(id)

    EditComment.run(
      comment: comment,
      content: content,
      actor: me
    ) do |operation, updated_comment|
      if (reason = operation.rejection_reason)
        return head 404 if reason.target_unavailable?
        return head 403 if reason.forbidden?
        return head 409 if reason.withdrawn?
      end

      return head 500 if updated_comment.nil?
    end

    context.response.headers["X-Draft-Saved"] = "true"

    q = CommentQuery.new.id(comment.id).preload_user
    q = q.preload_parent &.preload_user

    component(
      ::Comments::CardContent,
      formatter: formatter,
      comment: q.first,
      show_update_success: true,
    )
  end
end
