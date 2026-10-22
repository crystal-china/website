class Forum::Follows::Delete < BrowserAction
  delete "/forum/:topic_id/follow" do
    topic = TopicQuery.find(topic_id)
    me = current_user

    return head 403 if topic.user_id == me.id

    TopicFollowQuery.new.topic_id(topic.id).follower_id(me.id).delete

    component(
      Forum::FollowButton,
      topic: topic,
      following: false,
      current_user: me
    )
  end
end
