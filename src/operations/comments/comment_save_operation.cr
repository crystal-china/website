class Comment::SaveOperation
  include StoredContentHtml

  # 主题统计：新增由数据库 trigger 递增；软删除和 restore 在此重算。
  # 正文编辑和投票不重算统计。
  after_save do |comment|
    if !new_record? && soft_deleted_at.changed?
      TopicActivity.refresh comment.comment_thread!
    end
  end
end
