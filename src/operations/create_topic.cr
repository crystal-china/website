class CreateTopic < Topic::SaveOperation
  permit_columns user_id, node_id, title, content
  after_save create_comment_thread, if: :new_record?

  before_save do
    # 当前站点的主题统一归入默认 Space，不接受客户端指定其他 Space。
    space_id.value = Space::DEFAULT_ID

    validate_required user_id, node_id, title, content
  end

  after_save do |topic|
    NotificationDelivery.topic_created(
      topic,
      mentioned_login_names
    ) if new_record? && content.changed?

    if new_record?
      TopicReading.mark_as_read(
        topic_id: topic.id,
        user_id: topic.user_id,
        last_reply_id: topic.last_reply_id
      )
    end
  end

  private def create_comment_thread(topic : Topic) : Nil
    SaveCommentThread.create!(topic_id: topic.id)
  end
end
