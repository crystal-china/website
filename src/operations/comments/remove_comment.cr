class RemoveComment < Avram::Operation
  include CommentLocking
  include CommentVisibility

  needs comment : Comment
  needs actor : User

  enum RejectionReason
    TargetUnavailable
    Forbidden
    HasReplies
  end

  getter rejection_reason : RejectionReason?

  # 检查可见性、权限和回复数量后加锁删除；管理员同时删除全部后代。
  def run : Comment?
    unless comment_available?(comment)
      @rejection_reason = RejectionReason::TargetUnavailable

      return nil
    end

    unless comment.user_id == actor.id || actor.admin?
      @rejection_reason = RejectionReason::Forbidden

      return nil
    end

    unless actor.admin? || comment.deletable?
      @rejection_reason = RejectionReason::HasReplies

      return nil
    end

    deleted_comment : Comment? = nil

    transaction_committed = AppDatabase.transaction do
      target = find_and_lock_comment(comment)

      # 等待锁期间可能新增回复，按加锁后读取的数量再检查一次。
      # 普通用户仍受回复数量限制；管理员删除时连同全部后代一起软删除。
      unless actor.admin? || target.deletable?
        @rejection_reason = RejectionReason::HasReplies

        AppDatabase.rollback
      end

      deleted_comment = DeleteComment.delete!(
        target,
        actor_id: actor.id,
        delete_descendants: actor.admin?
      )
    end

    return nil unless transaction_committed

    deleted_comment
  end
end
