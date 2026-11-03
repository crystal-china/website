require "../actions/mixins/follow_helpers"

module NotificationDelivery
  include Rosetta::Translatable
  extend FollowHelpers

  def self.topic_created(topic : Topic, login_names : Array(String)) : Nil
    recipients = user_follow_recipients(topic.user_id, :followed_user_topic)

    mentioned_user_ids(login_names).each do |user_id|
      recipients[user_id] = :mention
    end

    deliver(topic, recipients, topic.user_id)
  end

  def self.comment_created(comment : Comment, login_names : Array(String)) : Nil
    # 接收通知的 user_id => 通知类型
    recipients = user_follow_recipients(comment.user_id, :followed_user_reply)
    thread = comment.comment_thread!

    # 这里使用哈希合并，为针对同一个人针对同一个 target 的通知去重。
    if (topic_id = thread.topic_id)
      # 关注用户 < 关注主题 < 主题作者 < 直接回复 < 明确提及，依次覆盖。
      topic_follower_query(topic_id).each do |follow|
        # （1） 类型为针对主题的关注
        recipients[follow.follower_id] = :followed_topic_reply
      end
      # （2） 主题作者回复覆盖 （1）
      recipients[TopicQuery.find(topic_id).user_id] = :topic_reply
    end

    if (parent_id = comment.parent_id)
      # （3） 针对评论的回复覆盖 （1）
      recipients[CommentQuery.find(parent_id).user_id] = :comment_reply
    end

    # 普通回复不通知自己；明确 @自己 时仍允许通知。
    recipients.delete(comment.user_id)

    mentioned_user_ids(login_names).each do |user_id|
      # (4) 最高优先级，直接提及
      recipients[user_id] = :mention
    end

    deliver(
      comment,
      recipients,
      comment.user_id
    )
  end

  def self.mentions_updated(record : Comment | Topic, actor_id : Int64, login_names : Array(String)) : Nil
    recipients = {} of Int64 => Notification::Kind

    mentioned_user_ids(login_names).each do |user_id|
      recipients[user_id] = :mention
    end

    deliver(
      record,
      recipients,
      actor_id
    )
  end

  def self.edited_by_admin(record : Comment | Topic, actor_id : Int64) : Nil
    kind = record.is_a?(Topic) ? Notification::Kind::TopicEdited : Notification::Kind::CommentEdited

    notify_author(
      record,
      actor_id,
      kind
    )
  end

  def self.topic_moved_by_admin(topic : Topic, actor_id : Int64) : Nil
    notify_author(
      topic,
      actor_id,
      :topic_moved,
      r(".new_node").t(name: NodeQuery.find(topic.node_id).name.to_s)
    )
  end

  def self.deleted_by_admin(record : Comment | Topic, actor_id : Int64) : Nil
    kind = record.is_a?(Topic) ? Notification::Kind::TopicDeleted : Notification::Kind::CommentDeleted

    notify_author(
      record,
      actor_id,
      kind
    )
  end

  private def self.notify_author(
    record : Comment | Topic,
    actor_id : Int64,
    kind : Notification::Kind,
    excerpt : String = record.content[0, 120],
  ) : Nil
    return if actor_id == record.user_id

    #  被操作的用户接受
    deliver(
      record,
      {record.user_id => kind},
      actor_id,
      excerpt
    )
  end

  private def self.deliver(
    record : Comment | Topic,
    recipients : Hash(Int64, Notification::Kind),
    actor_id : Int64,
    excerpt : String = record.content[0, 120],
  ) : Nil
    return if recipients.empty?

    if record.is_a?(Topic)
      topic_id = record.id
      comment_id = nil
      # 主题被编辑、移动节点、删除，或者正文里包含 @用户
      source_title = record.title
    else
      thread = record.comment_thread!
      topic_id = thread.topic_id
      comment_id = record.id

      source_title = if topic_id
                       # 回复、编辑、删除主题的评论，也使用主题标题。
                       TopicQuery.find(topic_id).title
                     else
                       # 文档，使用文档的 title 或独立文档的 path
                       doc = thread.doc!.not_nil!
                       DocNavigation.pages_by_path[doc.path_index]?.try(&.title) || doc.path_index
                     end
    end

    existing = existing_notifications(record, recipients)

    recipients.each do |user_id, kind|
      # 编辑主题或评论时，避免重复通知已经被 @过的人
      next if existing.includes?({user_id, kind})

      SaveNotification.create!(
        user_id: user_id,
        actor_id: actor_id,
        kind: kind,
        topic_id: topic_id,
        comment_id: comment_id,
        source_title: source_title,
        excerpt: excerpt
      )
    end
  end

  private def self.existing_notifications(
    record : Topic | Comment,
    recipients : Hash(Int64, Notification::Kind),
  ) : Set(Tuple(Int64, Notification::Kind))
    # 管理相关的类型，可以反复发生，不去重。
    recipients = recipients.select do |_, kind|
      case kind
      when .topic_reply?, .comment_reply?, .mention?, .followed_topic_reply?, .followed_user_topic?, .followed_user_reply?
        true
      else
        false
      end
    end
    existing = Set(Tuple(Int64, Notification::Kind)).new

    return existing if recipients.empty?

    query = NotificationQuery.new.for_target(record).user_id.in(recipients.keys).kind.in(recipients.values.uniq!)
    query.each do |notification|
      existing << {notification.user_id, notification.kind}
    end

    existing
  end

  private def self.user_follow_recipients(user_id : Int64, kind : Notification::Kind) : Hash(Int64, Notification::Kind)
    recipients = {} of Int64 => Notification::Kind

    user_follower_query(user_id).each do |follow|
      recipients[follow.follower_id] = kind
    end

    recipients
  end

  private def self.mentioned_user_ids(login_names : Array(String)) : Array(Int64)
    return [] of Int64 if login_names.empty?

    # 在合并提及收件人之前过滤，关闭提及通知的用户仍能收到正常回复通知。
    UserQuery.new.with_login_names(login_names)
      .mention_notifications_enabled(true)
      .id.asc_order.results.map(&.id)
  end
end
