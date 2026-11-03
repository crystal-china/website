class Forum::Follows::Delete < BrowserAction
  delete "/forum/:topic_id/follow" do
    topic = TopicQuery.find(topic_id)
    me = current_user

    return head 403 if topic.user_id == me.id

    my_followed_topic_query(topic.id).delete

    component(
      Forum::FollowButton,
      topic: topic,
      followed: false,
    )
  end
end
