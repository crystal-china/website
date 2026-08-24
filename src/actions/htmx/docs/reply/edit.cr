class Htmx::Docs::Reply::Edit < DocAction
  param user_id : Int64
  param order_by : String?

  get "/htmx/docs/reply/edit/:id" do
    me = current_user
    return head 401 if me.nil?
    return head 401 if user_id != me.id

    reply = ReplyQuery.find(id)

    return head 401 if user_id != reply.user_id

    component(
      ::Docs::ReplyToDocForm,
      current_user: current_user,
      content: reply.content,
      html_id: "reply_to_reply",
      order_by: order_by,
      reply_id: id.to_i64,
      doc_path: reply.preferences.path_for_doc?,
      # 只有子评论需要指定线程替换目标；顶级评论提交后替换文档的评论列表。
      target_reply_id: reply.reply_id ? reply.root_reply_id : nil,
    )
  end
end
