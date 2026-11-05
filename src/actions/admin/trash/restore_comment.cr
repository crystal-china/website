class Admin::Trash::RestoreComment < AdminAction
  post "/admin/trash/comments/:id/restore" do
    deleted_comment = CommentQuery.new.only_soft_deleted.id(id).first

    ::RestoreComment.run(deleted_comment: deleted_comment) do |operation, result|
      if result.nil?
        flash.failure = operation.errors[:base].first

        return component Shared::FlashMessages, flash: flash
      end

      remaining_comments = CommentQuery.new
        .only_soft_deleted
        .comment_thread_id(result[:comment].comment_thread_id)
        .soft_deleted_at(result[:deleted_at])

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
  end
end
