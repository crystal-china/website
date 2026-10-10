class Notification < BaseModel
  enum Kind
    TopicReply     = 1
    CommentReply   = 2
    Mention        = 3
    TopicEdited    = 4
    TopicMoved     = 5
    TopicDeleted   = 6
    CommentEdited  = 7
    CommentDeleted = 8
  end

  table do
    belongs_to user : User
    belongs_to actor : User
    column url : String
    column kind : Notification::Kind
    column source_title : String
    column excerpt : String
    column read_at : Time?
  end
end
