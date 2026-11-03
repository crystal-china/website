module TopicActivity
  def self.refresh(thread : CommentThread) : Nil
    topic_id = thread.topic_id

    return unless topic_id

    # 回填 task 也会直接调用它。那时没有外层保存事务，它需要自己建立事务，确保锁定 Topic 后再完成统计更新。
    AppDatabase.transaction do
      # 恢复删除的评论会触发 callback, 因此要包含已经删除的记录.
      topic = TopicQuery.new.with_soft_deleted.id(topic_id).for_update.first
      # 级联删除会将后代一起软删除，直接统计尚未删除的评论即可。
      comments = CommentQuery.new.comment_thread_id(thread.id)
      # 最后回复统一按 ID 选择，与新增回复的 trigger 保持一致。
      last_reply = comments.id.desc_order.first?

      TopicQuery.new.with_soft_deleted.id(topic.id).update(
        replies_count: comments.select_count.to_i,
        last_reply_user_id: last_reply.try(&.user_id),
        last_active_at: last_reply.try(&.created_at) || topic.created_at,
        updated_at: topic.updated_at
      )
    end
  end
end
