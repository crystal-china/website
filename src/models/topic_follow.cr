class TopicFollow < BaseModel
  table do
    belongs_to topic : Topic
    belongs_to follower : User
  end
end
