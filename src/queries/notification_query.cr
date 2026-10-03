class NotificationQuery < Notification::BaseQuery
  def for_display
    # 关联使用 BaseQuery，不套用 CommentQuery / TopicQuery 的 only_kept 默认条件。
    # 仍需载入删除记录，才能在通知中显示“相关内容已删除”。
    preload_actor.preload_topic.preload_comment do |query|
      query.preload_root.preload_comment_thread do |thread_query|
        thread_query.preload_doc.preload_topic
      end
    end
  end
end
