class CreateRootComment < Avram::Operation
  needs thread : CommentThread
  needs user_id : Int64
  needs content : String

  enum RejectionReason
    TargetUnavailable
  end

  getter rejection_reason : RejectionReason?

  # 检查所属主题或文档可访问后，创建根评论。
  def run : Comment?
    unless thread.target_visible?
      @rejection_reason = RejectionReason::TargetUnavailable

      return nil
    end

    CreateComment.create!(
      user_id: user_id,
      comment_thread_id: thread.id,
      content: content
    )
  end
end
