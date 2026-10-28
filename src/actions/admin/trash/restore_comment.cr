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

    remaining_comments = CommentQuery.new
      .only_soft_deleted
      .comment_thread_id(deleted_comment.comment_thread_id)
      .soft_deleted_at(deleted_comment.soft_deleted_at.not_nil!)

    flash.success = r(".comment_restored").t

    # HX-Trigger 是让浏览器“触发事件”，HTMX 收到后会触发指定的浏览器事件。
    # JSON 是“事件名称 + 携带的数据”，CommentCard 中的 hyperscript 接收这个事件
    # batch_empty = false → 只移除当前评论卡片
    # batch_empty = true  → 移除整个批次容器
    # hyperscript 里面，会通过  on trash:comment:restored(batch_empty) 监听，并传递 batch_empty 值进入 on ... end
    context.response.headers["HX-Trigger"] = {
      "trash:comment:restored" => {batch_empty: remaining_comments.none?},
    }.to_json

    component Shared::FlashMessages, flash: flash
  end

  private def parent_deleted?(deleted_comment : Comment) : Bool
    parent_id = deleted_comment.parent_id

    return false if parent_id.nil?

    CommentQuery.new.id(parent_id).none?
  end

  private def cannot_restore_response : Lucky::Response
    flash.failure = r(".cannot_restore").t

    component Shared::FlashMessages, flash: flash
  end
end
