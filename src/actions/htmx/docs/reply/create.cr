class Htmx::Docs::Reply::CreateOrUpdate < DocAction
  param user_id : Int64
  param content : String
  param order_by : String = "desc"
  param doc_path : String?
  param id : Int64?
  param op : String?

  # 回复评论按钮
  post "/htmx/docs/reply" do
    me = current_user
    return head 401 if me.nil?
    return head 401 if user_id != me.id
    return head 400 if content.blank?

    if !id.nil?
      reply = ReplyQuery.find(id.not_nil!)

      case op
      when "edit"
        SaveReply.update!(reply, content: content)
        path_for_doc = reply.preferences.path_for_doc?
        if path_for_doc.nil?
          # edit reply to reply
          root_reply = thread_root_reply(reply)
          id_or_doc_path = root_reply.id.to_s
          html_id = "doc_reply-#{root_reply.id}-replies"
        else
          # edit reply to doc
          id_or_doc_path = path_for_doc
          html_id = "replies"
        end
      when "new"
        # new reply to reply，这个是要新建回复的那个 reply
        root_reply = thread_root_reply(reply)
        id_or_doc_path = root_reply.id.to_s
        html_id = "doc_reply-#{root_reply.id}-replies"
        reply = SaveReply.create!(user_id: user_id, reply_id: reply.id, content: content)
      end
    else
      # 给 doc 新建评论
      doc_path = self.doc_path.not_nil!
      doc = DocQuery.new.path_index(doc_path).first
      id_or_doc_path = doc_path
      html_id = "replies"
      reply = SaveReply.create!(user_id: user_id, doc_id: doc.id, content: content)
    end

    pagination = replies_pagination(id_or_doc_path: id_or_doc_path.not_nil!, order_by: order_by)

    component(
      ::Docs::Replies,
      formatter: formatter,
      pagination: pagination,
      current_user: me,
      reply_id: reply.id,
      html_id: html_id.to_s
    )
  end
end
