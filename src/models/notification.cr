class Notification < BaseModel
  table do
    belongs_to user : User
    belongs_to actor : User
    belongs_to comment : Comment?
    belongs_to topic : Topic?
    column kind : String
    column read_at : Time?

    polymorphic target, associations: [:comment, :topic]
  end

  # 列表和点击入口使用相同的可见性规则，不能通过通知读到被隐藏的正文。
  def target_visible?
    if (comment = self.comment)
      return false if comment.soft_deleted?
      return false if comment.root.try(&.soft_deleted?)

      thread = comment.comment_thread
      if (topic = thread.topic)
        !topic.soft_deleted?
      else
        !thread.doc.not_nil!.content.nil?
      end
    else
      !self.topic.not_nil!.soft_deleted?
    end
  end

  def source_title
    if (comment = self.comment)
      thread = comment.comment_thread
      thread.topic.try(&.title) || thread.doc.not_nil!.path_index
    else
      self.topic.not_nil!.title
    end
  end
end
