class DeleteTopic < Topic::DeleteOperation
  attribute actor_id : Int64

  after_delete do |topic|
    NotificationDelivery.deleted_by_admin(topic, actor_id.value || topic.user_id)
  end
end
