class Comment::SaveOperation
  # 软删除和 restore 也经过此基类，统一维护统计；正文编辑和投票不触发。
  after_save do |comment|
    if new_record? || soft_deleted_at.changed?
      TopicActivity.refresh comment.comment_thread!
    end
  end
end
