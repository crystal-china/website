class SaveTopic < Topic::SaveOperation
  permit_columns user_id, title, content
  after_save create_comment_thread, if: :new_record?

  before_save do
    validate_required user_id, title, content
  end

  private def create_comment_thread(topic : Topic)
    SaveCommentThread.create!(topic_id: topic.id)
  end
end
