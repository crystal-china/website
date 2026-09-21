class Htmx::Comments::CreateOrUpdate < CommentAction
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
    return head 400 if content.blank?
    return head 400 if id.nil? && comment_thread_id.nil?

    root_comment : Comment? = nil

    if !id.nil?
      comment = CommentQuery.find(id.not_nil!)

      case op
      when "edit"
        # 编辑一条已有评论。这里 comment 可能是：
        # - CommentThread 的顶级评论
        # - 针对 comment 的子评论
        return head 403 if comment.user_id != me.id

        UpdateComment.update!(comment, content: content)

        q = CommentQuery.new.id(comment.id).preload_user
        q = q.preload_parent &.preload_user
        q = q.preload_votes &.user_id(me.id)

        return component(
          ::Comments::Card,
          formatter: formatter,
          comment: q.first,
          order_by: order_by,
          show_update_success: true,
          current_user: me
        )
      when "new"
        # 为一条已有评论新建子评论。这里的 comment 是“被回复的那条旧评论”。
        # 回复顶级评论时，它自己就是线程根；回复子评论时，继承该子评论所属的线程根。
        root_id = comment.root_id || comment.id
        comment = SaveComment.create!(user_id: me.id, parent_id: comment.id, content: content)
        pagination = comments_pagination(root_id: root_id, order_by: order_by)
        html_id = "comment-#{root_id}-comments"
        root_comment = CommentQuery.find(root_id)
      else
        return head 400
      end
    else
      # 给 CommentThread 新建顶级评论
      comment_thread_id = self.comment_thread_id.not_nil!
      CommentThreadQuery.find(comment_thread_id)
      comment = SaveComment.create!(user_id: me.id, comment_thread_id: comment_thread_id, content: content)
      pagination = comments_pagination(comment_thread_id: comment_thread_id, order_by: order_by)
      html_id = "comments"
    end

    if root_comment
      component(
        ::Comments::ChildCreated,
        formatter: formatter,
        pagination: pagination,
        current_user: me,
        comment_id: comment.id,
        root_comment: root_comment
      )
    else
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
end
