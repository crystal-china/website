class Forum::Follows::Create < BrowserAction
  post "/forum/:topic_id/follow" do
    topic = TopicQuery.find(topic_id)
    me = current_user

    return head 403 if topic.user_id == me.id

    SaveTopicFollow.upsert!(topic_id: topic.id, follower_id: me.id)

    component(
      Forum::FollowButton,
      topic: topic,
      followed: true,
    )
  end
end
