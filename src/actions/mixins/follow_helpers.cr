module FollowHelpers
  private def user_follower_query(user_id : Int64) : UserFollowQuery
    UserFollowQuery.new.followed_user_id(user_id)
  end

  private def followed_user_query(user_id : Int64) : UserFollowQuery
    UserFollowQuery.new.follower_id(user_id)
  end

  private def my_followed_user_query(user_id : Int64) : UserFollowQuery
    user_follower_query(user_id).merge_query(
      followed_user_query(current_user.not_nil!.id).query
    )
  end

  private def topic_follower_query(topic_id : Int64) : TopicFollowQuery
    TopicFollowQuery.new.topic_id(topic_id)
  end

  private def followed_topic_query(user_id : Int64) : TopicFollowQuery
    TopicFollowQuery.new.follower_id(user_id)
  end

  private def my_followed_topic_query(topic_id : Int64) : TopicFollowQuery
    topic_follower_query(topic_id).merge_query(
      followed_topic_query(current_user.not_nil!.id).query
    )
  end
end
