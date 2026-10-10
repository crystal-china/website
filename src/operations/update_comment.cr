class UpdateComment < Comment::SaveOperation
  permit_columns content

  # 仅用于本次操作，不写入 Comment；管理员编辑时不能把作者误记为操作者。
  attribute actor_id : Int64

  before_save do
    validate_required content
    edited_at.value = Time.utc if content.changed?
  end

  # 正文变化才发送编辑相关通知。
  after_save do |comment|
    if content.changed?
      actor_id = self.actor_id.value || comment.user_id

      NotificationDelivery.mentions_updated(comment, actor_id)
      NotificationDelivery.edited_by_admin(comment, actor_id)
    end
  end
end
