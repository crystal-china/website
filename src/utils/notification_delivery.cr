module NotificationDelivery
  def self.comment_created(comment : Comment)
    recipients = {} of Int64 => String
    thread = comment.comment_thread!

    if (topic_id = thread.topic_id)
      recipients[TopicQuery.find(topic_id).user_id] = "topic_reply"
    end
    if (parent_id = comment.parent_id)
      recipients[CommentQuery.find(parent_id).user_id] = "comment_reply"
    end
    UserMentions.user_ids(comment.content).each do |user_id|
      recipients[user_id] = "mention"
    end
    recipients.delete(comment.user_id)

    recipients.each do |user_id, kind|
      SaveNotification.create!(user_id: user_id, actor_id: comment.user_id, comment_id: comment.id, kind: kind)
    end
  end

  def self.mentions_updated(record : Comment | Topic)
    UserMentions.user_ids(record.content).each do |user_id|
      next if user_id == record.user_id

      if record.is_a?(Comment)
        next if NotificationQuery.new.user_id(user_id).comment_id(record.id).any?

        SaveNotification.create!(user_id: user_id, actor_id: record.user_id, comment_id: record.id, kind: "mention")
      else
        next if NotificationQuery.new.user_id(user_id).topic_id(record.id).any?

        SaveNotification.create!(user_id: user_id, actor_id: record.user_id, topic_id: record.id, kind: "mention")
      end
    end
  end
end
