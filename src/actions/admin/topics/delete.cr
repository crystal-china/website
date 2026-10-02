class Forum::Delete < BrowserAction
  delete "/forum/:id" do
    topic = TopicQuery.find(id)
    me = current_user

    return head 403 unless me.admin? || topic.user_id == me.id

    unless me.admin?
      comment_thread = CommentThreadQuery.new.topic_id(topic.id).first

      return head 409 if comment_thread.comments_query.with_soft_deleted.any?
    end

    DeleteTopic.delete!(topic)
    flash.success = "主题已删除"

    if context.request.headers["HX-Request"]?
      context.response.headers["HX-Redirect"] = Forum::Index.path
      head 200
    else
      redirect Forum::Index
    end
  end
end
