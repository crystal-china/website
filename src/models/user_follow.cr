class UserFollow < BaseModel
  table do
    belongs_to followed_user : User
    belongs_to follower : User
  end
end
