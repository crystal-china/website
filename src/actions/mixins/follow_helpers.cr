module FollowHelpers
  private def user_follow_query(user_id : Int64) : UserFollowQuery
    UserFollowQuery.new.followed_user_id(user_id).follower_id(current_user.not_nil!.id)
  end

  private def topic_follow_query(topic_id : Int64) : TopicFollowQuery
    TopicFollowQuery.new.topic_id(topic_id).follower_id(current_user.not_nil!.id)
  end
end
