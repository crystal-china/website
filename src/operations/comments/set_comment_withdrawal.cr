class SetCommentWithdrawal < Avram::Operation
  include CommentLocking

  needs comment_id : Int64
  needs actor : User
  needs withdrawn : Bool

  enum RejectionReason
    Forbidden
    TargetUnavailable
  end

  getter rejection_reason : RejectionReason?

  # 作者或管理员撤回、取消撤回公开可见的评论，保留正文和回复，返回更新后的评论。
  def run : Comment?
    updated_comment : Comment? = nil

    transaction_committed = AppDatabase.transaction do
      target = find_and_lock_comment(CommentQuery.find(comment_id))

      unless target.user_id == actor.id || actor.admin?
        @rejection_reason = RejectionReason::Forbidden

        AppDatabase.rollback
      end

      unless CommentQuery.new.id(target.id).publicly_visible_comments.any?
        @rejection_reason = RejectionReason::TargetUnavailable

        AppDatabase.rollback
      end

      updated_comment = Comment::SaveOperation.update!(target, withdrawn: withdrawn)
    end

    return nil unless transaction_committed

    updated_comment
  end
end
