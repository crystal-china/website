class DeleteComment < Comment::DeleteOperation
  attribute actor_id : Int64

  after_delete do |comment|
    NotificationDelivery.deleted_by_admin(comment, actor_id.value || comment.user_id)
  end
end
