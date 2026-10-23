class SaveTopicFollow < TopicFollow::SaveOperation
  upsert_lookup_columns :topic_id, :follower_id
end
