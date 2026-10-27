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

  # 每个删除批次只返回最大 ID 的评论；搜索任意成员，都定位到同一个批次入口。
  def deletion_batch_entries(keyword : String = "") : self
    # Avram 的等价构造方式，保留学习笔记；实际仍使用下面的 SQL。
    # batches = CommentQuery.new
    #   .only_soft_deleted
    #   .group(&.comment_thread_id)
    #   .group(&.soft_deleted_at)
    #
    # .query 返回 Avram::QueryBuilder，平常的 .group、.where 等方法，最终也是修改内部这个构造器
    # 这里直接访问它，是为了自定义 SELECT：
    # 之后的 batches.query.statement 直接得到 SQL 字符串。
    # batches.query.select_max(:id)
    # batch_ids = batches.query.statement
    batch_ids = <<-SQL
      SELECT MAX(id) FROM comments
      WHERE soft_deleted_at IS NOT NULL
      GROUP BY comment_thread_id, soft_deleted_at
      SQL

    if keyword.empty?
      only_soft_deleted.where("comments.id IN (#{batch_ids})")
    else
      only_soft_deleted.where(
        "comments.id IN (#{batch_ids} HAVING BOOL_OR(content ILIKE ?))",
        "%#{SqlLike.escape(keyword)}%"
      )
    end
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
