module NotificationDelivery
  def self.comment_created(comment : Comment)
    # 接收通知的 user_id => 通知类型
    recipients = {} of Int64 => Notification::Kind
    thread = comment.comment_thread!

    if (topic_id = thread.topic_id)
      recipients[TopicQuery.find(topic_id).user_id] = :topic_reply
    end

    if (parent_id = comment.parent_id)
      recipients[CommentQuery.find(parent_id).user_id] = :comment_reply
    end

    # 普通回复不通知自己；明确 @自己 时仍允许通知。
    recipients.delete(comment.user_id)

    mentioned_user_ids(comment).each do |user_id|
      recipients[user_id] = :mention
    end

    deliver(comment, recipients, comment.user_id)
  end

  def self.mentions_updated(record : Comment | Topic, actor_id : Int64)
    recipients = {} of Int64 => Notification::Kind

    mentioned_user_ids(record).each do |user_id|
      recipients[user_id] = :mention
    end

    deliver(record, recipients, actor_id)
  end

  def self.edited_by_admin(record : Comment | Topic, actor_id : Int64)
    kind = record.is_a?(Topic) ? Notification::Kind::TopicEdited : Notification::Kind::CommentEdited

    notify_author(record, actor_id, kind)
  end

  def self.topic_moved_by_admin(topic : Topic, actor_id : Int64)
    notify_author(topic, actor_id, :topic_moved, "新节点：#{NodeQuery.find(topic.node_id).name}")
  end

  def self.deleted_by_admin(record : Comment | Topic, actor_id : Int64)
    kind = record.is_a?(Topic) ? Notification::Kind::TopicDeleted : Notification::Kind::CommentDeleted

    notify_author(record, actor_id, kind)
  end

  private def self.notify_author(
    record : Comment | Topic,
    actor_id : Int64,
    kind : Notification::Kind,
    excerpt : String = record.content[0, 120],
  )
    return if actor_id == record.user_id

    #  被操作的用户接受
    deliver(record, {record.user_id => kind}, actor_id, excerpt)
  end

  private def self.deliver(
    record : Comment | Topic,
    recipients : Hash(Int64, Notification::Kind),
    actor_id : Int64,
    excerpt : String = record.content[0, 120],
  )
    return if recipients.empty?

    url = record.is_a?(Comment) ? Comments::Show.with(id: record.id).path : Forum::Show.with(id: record.id).path
    source_title = if record.is_a?(Topic)
                     # 主题被编辑、移动节点、删除，或者正文里包含 @用户
                     record.title
                   else
                     thread = record.comment_thread!

                     if (topic_id = thread.topic_id)
                       # 回复、编辑、删除主题的评论，也使用主题标题。
                       TopicQuery.find(topic_id).title
                     else
                       # 文档，使用文档的 title 或独立文档的 path
                       doc = thread.doc!.not_nil!
                       DocNavigation.pages_by_path[doc.path_index]?.try(&.title) || doc.path_index
                     end
                   end

    recipients.each do |user_id, kind|
      # 回复/提及只通知一次；管理操作可以针对同一内容反复发生，不去重。
      case kind
      when .topic_reply?, .comment_reply?, .mention?
        next if NotificationQuery.new.user_id(user_id).url(url).kind(kind).any?
      end

      SaveNotification.create!(
        user_id: user_id,
        actor_id: actor_id,
        kind: kind,
        url: url,
        source_title: source_title,
        excerpt: excerpt
      )
    end
  end

  private def self.mentioned_user_ids(record : Comment | Topic)
    user_ids = UserMentions.user_ids(record.content)

    return user_ids if user_ids.empty?

    # 在合并提及收件人之前过滤，关闭提及通知的用户仍能收到正常回复通知。
    UserQuery.new.id.in(user_ids).mention_notifications_enabled(true).results.map(&.id)
  end
end
