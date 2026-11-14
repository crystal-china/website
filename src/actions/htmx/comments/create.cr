# 给主题或文档的 CommentThread 新建顶级评论，成功后刷新主评论区。
class Htmx::Comments::Create < CommentAction
  param content : String = ""
  param order_by : String = "desc"
  param comment_thread_id : Int64?

  post "/htmx/comments" do
    me = current_user

    return head 401 if me.nil?
    return head 400 if content.blank?

    thread_id = comment_thread_id

    return head 400 if thread_id.nil?

    thread = CommentThreadQuery.find(thread_id)
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

    pagination = comments_pagination(comment_thread_id: thread_id, order_by: order_by)
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
end
