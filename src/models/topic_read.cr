class TopicRead < BaseModel
  table do
    belongs_to topic : Topic
    belongs_to user : User

    column last_read_reply_id : Int64
    column last_read_at : Time
  end
end
