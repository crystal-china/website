class SaveNotification < Notification::SaveOperation
  before_save do
    validate_required user_id, actor_id, kind, url, source_title, excerpt
  end
end
