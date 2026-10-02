module TopicActivity
  def self.refresh(thread : CommentThread)
    topic_id = thread.topic_id

    return unless topic_id

    # 回填 task 也会直接调用它。那时没有外层保存事务，它需要自己建立事务，确保锁定 Topic 后再完成统计更新。
    AppDatabase.transaction do
      # 恢复删除的评论会触发 callback, 因此要包含已经删除的记录.
      topic = TopicQuery.new.with_soft_deleted.id(topic_id).for_update.first
      comments = CommentQuery.new.comment_thread_id(thread.id)
      deleted_root_ids = comments.only_soft_deleted.parent_id.is_nil.map(&.id)

      # 根评论删除后，整个分支不可见；删除中间的子评论不隐藏其后代。
      unless deleted_root_ids.empty?
        comments = comments.where do |query|
          query.root_id.is_nil.or(&.root_id.not.in(deleted_root_ids))
        end
      end

      last_reply = comments.created_at.desc_order.id.desc_order.first?

      TopicQuery.new.with_soft_deleted.id(topic.id).update(
        replies_count: comments.select_count.to_i,
        last_reply_user_id: last_reply.try(&.user_id),
        last_active_at: last_reply.try(&.created_at) || topic.created_at,
        updated_at: topic.updated_at
      )
    end
  end
end
