class Forum::Update < ForumAction
  param content : String = ""

  put "/forum/:id" do
    topic = TopicQuery.find(id)

    return head 403 unless topic.user_id == current_user.id || current_user.admin?

    UpdateTopic.update(
      topic,
      params,
      content: content,
      actor_id: current_user.id
    ) do |operation, _updated_topic|
      if operation.saved?
        flash.success = r(".topic_updated").t

        redirect Forum::Show.with(id: topic.id)
      else
        build_failed_flash(operation)

        html(
          Forum::EditPage,
          topic: topic,
          operation: operation
        )
      end
    end
  end
end
