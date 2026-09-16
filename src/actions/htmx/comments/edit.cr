class Htmx::Comments::Edit < DocAction
  param user_id : Int64
  param order_by : String?

  get "/htmx/comments/edit/:id" do
    me = current_user
    return head 401 if me.nil?
    return head 403 if user_id != me.id

    comment = CommentQuery.find(id)

    return head 403 if comment.user_id != me.id

    component(
      ::Comments::Form,
      current_user: current_user,
      content: comment.content,
      html_id: "comment",
      order_by: order_by,
      comment_id: id.to_i64,
      # 只有子评论需要指定线程替换目标；顶级评论提交后替换所属 CommentThread 的评论列表。
      target_comment_id: comment.parent_id ? comment.root_id : nil,
    )
  end
end
