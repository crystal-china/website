class CommentQuery < Comment::BaseQuery
  include Avram::SoftDelete::Query

  def initialize
    defaults &.only_kept
  end

  def publicly_visible_topic_comments : self
    publicly_visible_comments.join_comment_thread(CommentThreadQuery.new.topic_id.is_not_nil)
  end

  def publicly_visible_comments : self
    # 删除时不留下未删除的后代，恢复时要求父评论存在；无需再 JOIN 根评论。
    # 当前评论由默认的 only_kept 过滤，所属主题／文档仍需单独检查。
    join_comment_thread(CommentThreadQuery.new.publicly_visible)
  end

  # 现在由级联删除和恢复顺序保证可见性，不再使用此 self JOIN 方案；保留代码供参考。
  # 这是另一个写法。
  # join_comment_thread(CommentThreadQuery.new.join_topic(TopicQuery.new)).where(<<-SQL)
  #     (comments.root_id IS NULL OR EXISTS (
  #       SELECT 1 FROM comments AS roots
  #       WHERE roots.id = comments.root_id AND roots.soft_deleted_at IS NULL
  #     ))
  #     SQL
  def with_visible_root : self
    # 删除根评论会隐藏整个分支, SQL 如下：
    # FROM comments
    # LEFT JOIN comments AS roots ON roots.id = comments.root_id
    # WHERE comments.soft_deleted_at IS NULL
    # AND roots.soft_deleted_at IS NULL

    #  CommentQuery 默认的 only_kept 已经检查了当前评论是否删除；这里的 where 是额外检查根评论，两者不重复。
    join(
      Avram::Join::Left.new(
        from: :comments,
        to: :comments,
        primary_key: :root_id,
        foreign_key: :id,
        alias_to: :roots
      )
    ).where("roots.soft_deleted_at IS NULL")
  end
end
