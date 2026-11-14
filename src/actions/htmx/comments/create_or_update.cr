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

    if (comment_id = id)
      comment = CommentQuery.find(comment_id)

      case op
      when "edit"
        edit_comment(comment, me)
      when "new"
        create_comment_reply(comment, me)
      else
        head 400
      end
    else
      create_root_comment(comment_thread_id.not_nil!, me)
    end
  end

  # 给 CommentThread 新建顶级评论
  private def create_root_comment(comment_thread_id : Int64, me : User) : Lucky::Response
    thread = CommentThreadQuery.find(comment_thread_id)

    comment = CreateRootComment.run(
      user_id: me.id,
      thread: thread,
      content: content
    ) do |operation, created_comment|
      if (reason = operation.rejection_reason)
        return head 404 if reason.target_unavailable?
      end

      return head 500 if created_comment.nil?

      created_comment
    end

    pagination = comments_pagination(comment_thread_id: comment_thread_id, order_by: order_by)
    topic : Topic? = nil

    if (topic_id = thread.topic_id)
      topic = TopicQuery.find(topic_id)
    end

    context.response.headers["X-Draft-Saved"] = "true"

    component(
      ::Comments::Created,
      formatter: formatter,
      pagination: pagination,
      comment_id: comment.id,
      topic: topic
    )
  end

  # 为一条已有评论新建子评论。这里的 comment 是“被回复的那条旧评论”。
  # 回复顶级评论时，它自己就是线程根；回复子评论时，继承该子评论所属的线程根。
  private def create_comment_reply(comment : Comment, me : User) : Lucky::Response
    root_id = comment.root_id || comment.id
    reply = CreateCommentReply.run(
      parent: comment,
      user_id: me.id,
      content: content
    ) do |operation, reply|
      if (reason = operation.rejection_reason)
        return head 404 if reason.target_unavailable?
      end

      return head 500 if reply.nil?

      reply
    end

    pagination = comments_pagination(root_id: root_id, order_by: order_by)
    root_comment = CommentQuery.find(root_id)

    context.response.headers["X-Draft-Saved"] = "true"

    component(
      ::Comments::ChildCreated,
      formatter: formatter,
      pagination: pagination,
      comment_id: reply.id,
      root_comment: root_comment
    )
  end

  # 编辑一条已有评论。这里 comment 可能是：
  # - CommentThread 的顶级评论
  # - 针对 comment 的子评论
  private def edit_comment(comment : Comment, me : User) : Lucky::Response
    EditComment.run(
      comment: comment,
      content: content,
      actor: me
    ) do |operation, updated_comment|
      if (reason = operation.rejection_reason)
        return head 404 if reason.target_unavailable?
        return head 403 if reason.forbidden?
        return head 409 if reason.withdrawn?
      end

      return head 500 if updated_comment.nil?
    end

    context.response.headers["X-Draft-Saved"] = "true"

    q = CommentQuery.new.id(comment.id).preload_user
    q = q.preload_parent &.preload_user

    component(
      ::Comments::CardContent,
      formatter: formatter,
      comment: q.first,
      show_update_success: true,
    )
  end
end
