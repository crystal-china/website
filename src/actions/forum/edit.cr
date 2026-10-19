class Forum::Edit < ForumAction
  get "/forum/:id/edit" do
    topic = TopicQuery.find(id)

    return head 403 unless topic.user_id == current_user.id || current_user.admin?

    html(
      Forum::EditPage,
      topic: topic,
      operation: UpdateTopic.new(topic)
    )
  end
end
