class CreateTopic < Topic::SaveOperation
  permit_columns user_id, node_id, title, content
  after_save create_comment_thread, if: :new_record?

  before_save do
    validate_required user_id, node_id, title, content
  end

  after_save do |topic|
    NotificationDelivery.mentions_updated(topic, topic.user_id) if new_record? && content.changed?
  end

  private def create_comment_thread(topic : Topic)
    SaveCommentThread.create!(topic_id: topic.id)
  end
end
