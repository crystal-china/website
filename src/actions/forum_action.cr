abstract class ForumAction < BrowserAction
  expose nodes

  private def nodes : Array(Node)
    NodeQuery.new.sorted.results
  end

  private def render_saved_topic(topic : Topic) : Lucky::Response
    path = Forum::Show.with(id: topic.id).path
    topic = TopicQuery.new.id(topic.id).preload_user.preload_node.first

    context.response.headers["X-Draft-Saved"] = "true"
    context.response.headers["HX-Push-Url"] = path

    # 保存时可能产生 @自己的通知，直接返回的详情页需使用更新后的铃铛计数。
    render_topic(topic, current_user: current_user.try(&.reload))
  end

  # html 的 expose 使用同名参数；保存后传入新对象，普通访问沿用当前用户。
  private def render_topic(
    topic : Topic,
    *,
    followed_topics : Bool = false,
    only_show_unread : Bool = false,
    current_user : User? = self.current_user,
  ) : Lucky::Response
    comment_thread = CommentThreadQuery.new.topic_id(topic.id).first
    can_delete_topic = false
    topic_followed = false
    author_followed = false

    if (me = current_user)
      can_delete_topic = me.admin? || (me.id == topic.user_id && topic.replies_count.zero?)

      if me.id != topic.user_id
        topic_followed = my_followed_topic_query(topic.id).any?
        author_followed = my_followed_user_query(topic.user_id).any?
      end
    end

    if me
      AppDatabase.transaction do
        # 浏览主题才同步通知；新增主题／评论的 callback 只记录阅读位置。
        if me.unread_notifications_count > 0
          notifications = NotificationQuery.new.user_id(me.id).unread_in_topic(
            topic.id,
            last_read_reply_id: topic.last_reply_id
          )
          read_count = notifications.update(read_at: Time.utc)

          # trigger 已更新计数，页面和铃铛必须使用新对象。
          current_user = me.reload if read_count > 0
        end

        TopicReading.mark_as_read(
          topic_id: topic.id,
          user_id: me.id,
          last_reply_id: topic.last_reply_id
        )
      end
    end

    html(
      Forum::ShowPage,
      topic: topic,
      comment_thread: comment_thread,
      can_delete_topic: can_delete_topic,
      topic_followed: topic_followed,
      author_followed: author_followed,
      followed_topics: followed_topics,
      only_show_unread: only_show_unread
    )
  end
end
