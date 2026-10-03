class SaveNotification < Notification::SaveOperation
  before_save do
    validate_required user_id, actor_id, kind
    validate_inclusion_of kind, in: ["topic_reply", "comment_reply", "mention"]
    if comment_id.value.nil? == topic_id.value.nil?
      add_error :target, "必须且只能指定一个通知目标"
    end
  end
end
