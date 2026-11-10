module CommentCreation
  # 初始化新评论的投票数据，并检查是否同时指定了评论区和父评论。
  private def prepare_new_comment : Nil
    if parent_id.value && comment_thread_id.value
      add_error :comment_thread_id_or_parent_id, r("validations.comment_target_conflict").t
    end

    vote_counts.value = Comment::VoteCounts.from_json(
      {
        👍:  0,
        👎:  0,
        😄:  0,
        ❤️: 0,
        🎉:  0,
        😕:  0,
        👀️: 0,
      }.to_json
    )
  end

  # 新增才发送回复通知。
  private def notify_comment_created(comment : Comment) : Nil
    NotificationDelivery.comment_created(comment, mentioned_login_names)

    # 作者自己的新回复直接标为已读；文档评论不写主题阅读记录。
    if (topic_id = comment.comment_thread!.topic_id)
      TopicReading.mark_as_read(
        topic_id: topic_id,
        user_id: comment.user_id,
        last_reply_id: comment.id
      )
    end
  end
end
