class SaveNotification < Notification::SaveOperation
  before_save do
    validate_required user_id, actor_id, kind, source_title, excerpt
    validate_required topic_id if comment_id.value.nil?
  end
end
