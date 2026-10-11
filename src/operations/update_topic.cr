class UpdateTopic < Topic::SaveOperation
  permit_columns node_id, title, content

  # 仅用于本次操作，不写入 Topic；Action 从当前登录用户传入，不能信任表单中的操作者。
  attribute actor_id : Int64

  before_save do
    validate_required node_id, title, content
    edited_at.value = Time.utc if title.changed? || content.changed?
  end

  after_save do |topic|
    actor_id = self.actor_id.value || topic.user_id

    NotificationDelivery.mentions_updated(topic, actor_id) if content.changed?
    NotificationDelivery.edited_by_admin(topic, actor_id) if title.changed? || content.changed?
    NotificationDelivery.topic_moved_by_admin(topic, actor_id) if node_id.changed?
  end
end
