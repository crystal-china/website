class CreateCommentReply < Avram::Operation
  include CommentLocking
  include CommentVisibility

  needs parent : Comment
  needs user_id : Int64
  needs content : String

  enum RejectionReason
    TargetUnavailable
  end

  getter rejection_reason : RejectionReason?

  # 检查父评论可访问后，锁住根评论和父评论，在同一个事务中保存回复。
  def run : Comment?
    unless comment_available?(parent)
      @rejection_reason = RejectionReason::TargetUnavailable

      return nil
    end

    reply : Comment? = nil

    transaction_committed = AppDatabase.transaction do
      # 重新读取并锁住未软删除的父评论。
      locked_parent = find_and_lock_comment(parent)

      reply = ReplyToComment.create!(
        user_id: user_id,
        parent_id: locked_parent.id,
        content: content
      )
    end

    return nil unless transaction_committed

    reply
  end
end
