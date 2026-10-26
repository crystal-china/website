class Admin::Trash::RestoreComment < AdminAction
  post "/admin/trash/comments/:id/restore" do
    deleted_comments_query = CommentQuery.new.only_soft_deleted.id(id)
    deleted_comment = deleted_comments_query.first
    thread = CommentThreadQuery.find(deleted_comment.comment_thread_id)

    # 已经确定不可恢复时直接返回，不进入加锁流程。
    return cannot_restore_response unless thread.target_visible?
    return cannot_restore_response if parent_deleted?(deleted_comment)

    AppDatabase.transaction do
      # 与删除、回复保持一致：先锁根评论，再锁目标，避免检查父评论后它又被删除。
      if (root_id = deleted_comment.root_id)
        root_comment = CommentQuery.new.id(root_id).for_update.first?

        # 例如：

        # A：根评论，存在
        # └── B：已删除，正在请求恢复

        # 1. 恢复请求检查 B 的父评论 A：未删除，通过。
        # 2. 另一个请求删除 A：B 已删除，没有可见回复，因此允许。
        # 3. 恢复请求再查询并锁定 A：默认过滤已删除记录，得到 nil。
        return cannot_restore_response if root_comment.nil?
      end

      deleted_comment = deleted_comments_query.for_update.first

      # 等待锁期间，所属内容或父评论可能变得不可访问，恢复前必须重新检查。
      return cannot_restore_response unless thread.target_visible?
      return cannot_restore_response if parent_deleted?(deleted_comment)

      deleted_comment.restore
    end

    flash.success = r(".comment_restored").t

    redirect Admin::Trash::Index
  end

  private def parent_deleted?(deleted_comment : Comment) : Bool
    parent_id = deleted_comment.parent_id

    return false if parent_id.nil?

    CommentQuery.new.id(parent_id).none?
  end

  private def cannot_restore_response : Lucky::Response
    flash.failure = r(".cannot_restore").t

    redirect Admin::Trash::Index
  end
end
