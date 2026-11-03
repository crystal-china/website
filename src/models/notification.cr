class Notification < BaseModel
  enum Kind
    TopicReply         =  1
    CommentReply       =  2
    Mention            =  3
    TopicEdited        =  4
    TopicMoved         =  5
    TopicDeleted       =  6
    CommentEdited      =  7
    CommentDeleted     =  8
    FollowedTopicReply =  9
    FollowedUserTopic  = 10
    FollowedUserReply  = 11
  end

  table do
    belongs_to user : User
    belongs_to actor : User
    # 保留历史目标 ID，不设级联外键；目标删除后通知仍可显示，点击时返回 404。
    column topic_id : Int64?
    column comment_id : Int64?
    column kind : Notification::Kind
    column source_title : String
    column excerpt : String
    column read_at : Time?
  end

  def url : String
    if (id = comment_id)
      Comments::Show.with(id: id).path
    else
      Forum::Show.with(id: topic_id.not_nil!).path
    end
  end
end
