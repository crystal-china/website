class CommentQuery < Comment::BaseQuery
  include Avram::SoftDelete::Query

  def initialize
    defaults &.only_kept
  end

  def publicly_visible_topic_comments : self
    publicly_visible_comments.join_comment_thread(CommentThreadQuery.new.topic_id.is_not_nil)
  end

  def publicly_visible_comments : self
    # 先检查，评论所属主题是否可见？（即：如果主题被软删除，那么它级联的记录全部不可访问）
    query = join_comment_thread(CommentThreadQuery.new.publicly_visible)

    # 除非它是一个子评论，此时进入下一轮判断。
    # 如果是子评论，要判断它 root 评论是否可见。
    query.with_visible_root
  end

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
