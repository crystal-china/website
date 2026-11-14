class Htmx::Comments::Delete < CommentAction
  param order_by : String = "desc"

  delete "/htmx/comments/:id" do
    me = current_user

    return head 401 if me.nil?

    comment = CommentQuery.find(id)

    comment = RemoveComment.run(
      comment: comment,
      actor: me
    ) do |operation, deleted_comment|
      if (reason = operation.rejection_reason)
        return head 404 if reason.target_unavailable?
        return head 403 if reason.forbidden?
        return head 409 if reason.has_replies?
      end

      return head 500 if deleted_comment.nil?

      deleted_comment
    end

    # 删除后原来的分页位置可能移动，单纯从页面移除卡片会造成下一页漏项。
    root_comment : Comment? = nil
    topic : Topic? = nil

    if (root_id = comment.root_id)
      pagination = comments_pagination(root_id: root_id, order_by: order_by)
      root_comment = CommentQuery.find(root_id)
    else
      pagination = comments_pagination(comment_thread_id: comment.comment_thread_id, order_by: order_by)
      thread = CommentThreadQuery.find(comment.comment_thread_id)

      if (topic_id = thread.topic_id)
        topic = TopicQuery.find(topic_id)
      end
    end

    component(
      ::Comments::Deleted,
      formatter: formatter,
      pagination: pagination,
      root_comment: root_comment,
      topic: topic,
    )
  end
end
