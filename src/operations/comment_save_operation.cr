class Comment::SaveOperation
  # 新增由数据库 trigger 递增统计；软删除和 restore 在此重算，正文编辑和投票不触发。
  after_save do |comment|
    if !new_record? && soft_deleted_at.changed?
      TopicActivity.refresh comment.comment_thread!
    end
  end
end
