class CommentThreadQuery < CommentThread::BaseQuery
  def publicly_visible : self
    # 文档没有 Topic，仍保留；主题存在时，使用 TopicQuery 的默认软删除过滤。
    # 文档正文为 NULL 表示来源缺失；空字符串仍是有效正文。

    # • 不是文档评论：放行，Topic 是否删除, 由 TopicQuery.new 检查
    # • 是文档评论：要求文档内容不是 NULL（文档正文为 NULL 表示对应的 Markdown 源文件已经不存在）
    left_join_topic(TopicQuery.new)
      .left_join_doc
      .where("(comment_threads.doc_id IS NULL OR docs.content IS NOT NULL)")
  end
end
