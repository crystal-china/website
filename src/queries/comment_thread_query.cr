class CommentThreadQuery < CommentThread::BaseQuery
  def publicly_visible : self
    # 文档没有 Topic，仍保留；主题存在时，使用 TopicQuery 的默认软删除过滤。
    left_join_topic(TopicQuery.new)
  end
end
