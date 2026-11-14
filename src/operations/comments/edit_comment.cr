class EditComment < Avram::Operation
  include CommentVisibility

  needs comment : Comment
  needs actor : User
  needs content : String

  enum RejectionReason
    TargetUnavailable
    Forbidden
    Withdrawn
  end

  getter rejection_reason : RejectionReason?

  # 检查可见性、编辑权限和撤回状态后，保存评论正文。
  def run : Comment?
    unless comment_available?(comment)
      @rejection_reason = RejectionReason::TargetUnavailable

      return nil
    end

    unless comment.user_id == actor.id || actor.admin?
      @rejection_reason = RejectionReason::Forbidden

      return nil
    end

    if comment.withdrawn?
      @rejection_reason = RejectionReason::Withdrawn

      return nil
    end

    UpdateComment.update!(
      comment,
      content: content,
      actor_id: actor.id
    )
  end
end
