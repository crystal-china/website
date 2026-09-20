class Htmx::Comments::New < CommentAction
  param order_by : String?
  param id : Int64

  get "/htmx/comments/new" do
    me = current_user
    return head 401 if me.nil?

    comment = CommentQuery.find(id)
    # target_comment_id 用于确定提交成功后替换哪个线程：顶级评论用自身 ID，子评论用所属根 ID。
    target_comment_id = comment.root_id || comment.id

    component(
      ::Comments::Form,
      current_user: me,
      html_id: "comment",
      order_by: order_by,
      comment_id: comment.id,
      target_comment_id: target_comment_id
    )
  end
end
