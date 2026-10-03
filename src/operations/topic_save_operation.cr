class Topic::SaveOperation
  after_save do |topic|
    NotificationDelivery.mentions_updated(topic) if content.changed?
  end
end
