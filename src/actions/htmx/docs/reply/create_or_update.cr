class Htmx::Comments::CreateOrUpdate < DocAction
  param user_id : Int64
  param content : String
  param order_by : String = "desc"
  param doc_path : String?
  param id : Int64?
  param op : String?

  # 统一处理 3 种提交：
  # - 给 doc 新建顶级评论
  # - 给某条已有评论新建子评论
  # - 编辑某条已有评论（可能是顶级评论，也可能是子评论）
  post "/htmx/comments" do
    me = current_user
    return head 401 if me.nil?
    return head 403 if user_id != me.id
    return head 400 if content.blank?

    if !id.nil?
      comment = CommentQuery.find(id.not_nil!)

      case op
      when "edit"
        # 编辑一条已有评论。这里 comment 可能是：
        # - 针对 doc 的顶级评论
        # - 针对 comment 的子评论
        return head 403 if comment.user_id != me.id

        SaveComment.update!(comment, content: content)
        path_for_doc = comment.preferences.path_for_doc?
        if path_for_doc.nil?
          # 编辑子评论
          # 子评论创建时已经保存所属线程，因此编辑后直接刷新这个根评论下的整个子评论列表。
          root_id = comment.root_id.not_nil!
          id_or_doc_path = root_id.to_s
          html_id = "comment-#{root_id}-comments"
        else
          # 编辑顶级评论
          id_or_doc_path = path_for_doc
          html_id = "comments"
        end
      when "new"
        # 为一条已有评论新建子评论。这里的 comment 是“被回复的那条旧评论”。
        # 回复顶级评论时，它自己就是线程根；回复子评论时，继承该子评论所属的线程根。
        root_id = comment.root_id || comment.id
        id_or_doc_path = root_id.to_s
        html_id = "comment-#{root_id}-comments"
        comment = SaveComment.create!(user_id: user_id, parent_id: comment.id, content: content)
      else
        return head 400
      end
    else
      # 给 doc 新建评论
      doc_path = self.doc_path.not_nil!
      doc = DocQuery.new.path_index(doc_path).first
      id_or_doc_path = doc_path
      html_id = "comments"
      comment = SaveComment.create!(user_id: user_id, doc_id: doc.id, content: content)
    end

    pagination = comments_pagination(id_or_doc_path: id_or_doc_path.not_nil!, order_by: order_by)

    component(
      ::Comments::List,
      formatter: formatter,
      pagination: pagination,
      current_user: me,
      comment_id: comment.id,
      html_id: html_id.to_s
    )
  end
end
