class NotificationQuery < Notification::BaseQuery
  # 主题通知不包含其评论通知；评论 ID 在整个 comments 表中唯一。
  def for_target(record : Topic | Comment) : self
    if record.is_a?(Comment)
      comment_id(record.id)
    else
      topic_id(record.id).comment_id.is_nil
    end
  end

  # 查询指定 topic 的未读的通知。
  def unread_in_topic(topic_id : Int64, *, last_read_reply_id : Int64?) : self
    topic_id(topic_id).read_at.is_nil.where do |query|
      query.comment_id.is_nil.or(&.comment_id.lte(last_read_reply_id || 0_i64))
    end
  end
end
