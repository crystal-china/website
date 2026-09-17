class Htmx::Comments::CreateOrUpdate < DocAction
  param user_id : Int64
  param content : String
  param order_by : String = "desc"
  param comment_thread_id : Int64?
  param id : Int64?
  param op : String?

  # 统一处理 3 种提交：
  # - 给 CommentThread 新建顶级评论
  # - 给某条已有评论新建子评论
  # - 编辑某条已有评论（可能是顶级评论，也可能是子评论）
  post "/htmx/comments" do
    me = current_user
    return head 401 if me.nil?
    return head 403 if user_id != me.id
    return head 400 if content.blank?
    return head 400 if id.nil? && comment_thread_id.nil?

    if !id.nil?
      comment = CommentQuery.find(id.not_nil!)

      case op
      when "edit"
        # 编辑一条已有评论。这里 comment 可能是：
        # - CommentThread 的顶级评论
        # - 针对 comment 的子评论
        return head 403 if comment.user_id != me.id

        UpdateComment.update!(comment, content: content)

        if comment.parent_id
          # 编辑子评论
          # 子评论创建时已经保存所属线程，因此编辑后直接刷新这个根评论下的整个子评论列表。
          root_id = comment.root_id.not_nil!
          pagination = comments_pagination(root_id: root_id, order_by: order_by)
          html_id = "comment-#{root_id}-comments"
        else
          # 编辑 CommentThread 的顶级评论
          pagination = comments_pagination(comment_thread_id: comment.comment_thread_id, order_by: order_by)
          html_id = "comments"
        end
      when "new"
        # 为一条已有评论新建子评论。这里的 comment 是“被回复的那条旧评论”。
        # 回复顶级评论时，它自己就是线程根；回复子评论时，继承该子评论所属的线程根。
        root_id = comment.root_id || comment.id
        pagination = comments_pagination(root_id: root_id, order_by: order_by)
        html_id = "comment-#{root_id}-comments"
        comment = SaveComment.create!(user_id: user_id, parent_id: comment.id, content: content)
      else
        return head 400
      end
    else
      # 给 CommentThread 新建顶级评论
      comment_thread_id = self.comment_thread_id.not_nil!
      CommentThreadQuery.find(comment_thread_id)
      pagination = comments_pagination(comment_thread_id: comment_thread_id, order_by: order_by)
      html_id = "comments"
      comment = SaveComment.create!(user_id: user_id, comment_thread_id: comment_thread_id, content: content)
    end

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
