class Htmx::Docs::Reply::Edit < DocAction
  param user_id : Int64

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
      reply_id: id.to_i64,
      doc_path: reply.preferences.path_for_doc?,
      target_reply_id: reply.reply_id ? thread_root_reply(reply).id : nil,
    )
  end
end
