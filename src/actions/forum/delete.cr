class Forum::Delete < BrowserAction
  delete "/forum/:id" do
    topic = TopicQuery.find(id)
    me = current_user

    return head 403 unless me.admin? || topic.user_id == me.id

    return head 409 unless me.admin? || topic.replies_count.zero?

    DeleteTopic.delete!(topic, actor_id: me.id)
    flash.success = r(".topic_deleted").t

    if context.request.headers["HX-Request"]?
      context.response.headers["HX-Redirect"] = Forum::Index.path
      head 200
    else
      redirect Forum::Index
    end
  end
end
