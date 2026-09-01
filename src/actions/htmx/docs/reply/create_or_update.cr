class Htmx::Docs::Reply::CreateOrUpdate < DocAction
  param user_id : Int64
  param content : String
  param order_by : String = "desc"
  param doc_path : String?
  param id : Int64?
  param op : String?

  # 统一处理 3 种提交：
  # - 给 doc 新建顶级评论
  # - 给某条已有 reply 新建子评论
  # - 编辑某条已有评论（可能是顶级评论，也可能是子评论）
  post "/htmx/docs/reply" do
    me = current_user
    return head 401 if me.nil?
    return head 403 if user_id != me.id
    return head 400 if content.blank?

    if !id.nil?
      reply = ReplyQuery.find(id.not_nil!)

      case op
      when "edit"
        # 编辑一条已有评论。这里 reply 可能是：
        # - 针对 doc 的顶级评论
        # - 针对 reply 的子评论
        return head 403 if reply.user_id != me.id

        SaveReply.update!(reply, content: content)
        path_for_doc = reply.preferences.path_for_doc?
        if path_for_doc.nil?
          # edit reply to reply
          # 子评论创建时已经保存所属线程，因此编辑后直接刷新这个根评论下的整个子评论列表。
          root_reply_id = reply.root_reply_id.not_nil!
          id_or_doc_path = root_reply_id.to_s
          html_id = "doc_reply-#{root_reply_id}-replies"
        else
          # edit reply to doc
          id_or_doc_path = path_for_doc
          html_id = "replies"
        end
      when "new"
        # 为一条已有 reply 新建子评论。这里的 reply 是“被回复的那条旧评论”。
        # 回复顶级评论时，它自己就是线程根；回复子评论时，继承该子评论所属的线程根。
        root_reply_id = reply.root_reply_id || reply.id
        id_or_doc_path = root_reply_id.to_s
        html_id = "doc_reply-#{root_reply_id}-replies"
        reply = SaveReply.create!(user_id: user_id, reply_id: reply.id, content: content)
      else
        return head 400
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
