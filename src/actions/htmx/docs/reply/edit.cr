class Htmx::Docs::Reply::Edit < DocAction
  param user_id : Int64
  param order_by : String?

  get "/htmx/docs/reply/edit/:id" do
    me = current_user
    return head 401 if me.nil?
    return head 403 if user_id != me.id

    comment = CommentQuery.find(id)

    return head 403 if comment.user_id != me.id

    component(
      ::Comments::Form,
      current_user: current_user,
      content: comment.content,
      html_id: "reply_to_reply",
      order_by: order_by,
      comment_id: id.to_i64,
      doc_path: comment.preferences.path_for_doc?,
      # 只有子评论需要指定线程替换目标；顶级评论提交后替换文档的评论列表。
      target_comment_id: comment.parent_id ? comment.root_id : nil,
    )
  end
end
