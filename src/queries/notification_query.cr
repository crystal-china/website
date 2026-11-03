class NotificationQuery < Notification::BaseQuery
  # 主题通知不包含其评论通知；评论 ID 在整个 comments 表中唯一。
  def for_target(record : Topic | Comment) : self
    if record.is_a?(Comment)
      comment_id(record.id)
    else
      topic_id(record.id).comment_id.is_nil
    end
  end
end
