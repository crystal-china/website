class Htmx::Docs::Reply::New < DocAction
  param user_id : Int64
  param doc_path : String?
  param id : Int64?

  get "/htmx/docs/reply/new" do
    me = current_user
    return head 401 if me.nil?
    return head 401 if user_id != me.id
    return head 401 if doc_path.nil? && id.nil?

    reply : ::Reply? = nil
    target_reply_id = nil

    # 根据 doc_path 是否存在，判断这是针对 doc 的回复还是针对评论的回复
    if doc_path.nil?
      # reply 的回复
      html_id = "reply_to_reply"
      reply = ReplyQuery.find(id.not_nil!)
      target_reply_id = thread_root_reply(reply).id
    else
      # doc 的回复
      html_id = "tab"
    end

    component(
      ::Docs::ReplyToDocForm,
      current_user: me,
      html_id: html_id,
      doc_path: doc_path,
      reply_id: reply.try &.id,
      target_reply_id: target_reply_id
    )
  end
end
