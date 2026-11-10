class RestoreComment < Avram::Operation
  needs deleted_comment : Comment

  # 恢复一条软删除评论，返回恢复后的评论和原删除时间，用于识别删除批次。
  def run : NamedTuple(comment: Comment, deleted_at: Time)?
    deleted_comments_query = CommentQuery.new.only_soft_deleted.id(deleted_comment.id)
    thread = CommentThreadQuery.find(deleted_comment.comment_thread_id)
    result : NamedTuple(comment: Comment, deleted_at: Time)? = nil

    # 已经确定不可恢复时直接返回，不进入加锁流程。
    return cannot_restore unless thread.target_visible?
    return cannot_restore if parent_deleted?(deleted_comment)

    transaction_committed = AppDatabase.transaction do
      # 与删除、回复保持一致：先锁根评论，再锁目标，避免检查父评论后它又被删除。
      if (root_id = deleted_comment.root_id)
        root_comment = CommentQuery.new.id(root_id).for_update.first?

        # 例如：

        # A：根评论，存在
        # └── B：已删除，正在请求恢复

        # 1. 恢复请求检查 B 的父评论 A：未删除，通过。
        # 2. 另一个请求删除 A：B 已删除，没有可见回复，因此允许。
        # 3. 恢复请求再查询并锁定 A：默认过滤已删除记录，得到 nil。
        return cannot_restore if root_comment.nil?
      end

      locked_deleted_comment = deleted_comments_query.for_update.first

      # 等待锁期间，所属内容或父评论可能变得不可访问，恢复前必须重新检查。
      return cannot_restore unless thread.target_visible?
      return cannot_restore if parent_deleted?(locked_deleted_comment)

      deleted_at = locked_deleted_comment.soft_deleted_at.not_nil!
      restored_comment = locked_deleted_comment.restore
      result = {comment: restored_comment, deleted_at: deleted_at}
    end

    return cannot_restore unless transaction_committed

    result
  end

  private def parent_deleted?(deleted_comment : Comment) : Bool
    parent_id = deleted_comment.parent_id

    return false if parent_id.nil?

    CommentQuery.new.id(parent_id).none?
  end

  private def cannot_restore : Nil
    add_error :base, r("validations.comment_cannot_be_restored").t
  end
end
