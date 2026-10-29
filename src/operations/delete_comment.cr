class DeleteComment < Comment::DeleteOperation
  attribute actor_id : Int64
  # 只由服务端管理员删除入口开启，不读取客户端参数。
  attribute delete_descendants : Bool = false

  before_delete do
    # 内部 task 也不能单独删除有回复的评论；重新读取 trigger 更新后的计数。
    unless delete_descendants.value || record.reload.deletable?
      add_error :base, r("validations.comment_has_replies").t
    end
  end

  after_delete do |comment|
    soft_delete_descendants(comment) if delete_descendants.value

    NotificationDelivery.deleted_by_admin(comment, actor_id.value || comment.user_id)
  end

  # 用递归 CTE 沿 parent_id 找到全部后代, 记录本身已经由 Avram 软删除，这里只处理它的后代
  # 依赖 parent_id 创建索引
  # 假设全表有 N 条评论，目标下面有 K 条后代，深度为 H：
  # • 有 parent_id 索引时，递归查找通常可以粗略理解为 O(K log N)。
  # • 没有该索引时，可能每层都扫描评论表，接近 O(H × N)。
  private def soft_delete_descendants(deleted_comment : Comment) : Nil
    # 按 parent_id 找整支，而不是 root_id，避免误删同一根评论下的其他分支。
    # 递归穿过已删除节点，只更新未删除记录，保留以前的删除时间。
    result = AppDatabase.exec(
      <<-SQL,
        WITH RECURSIVE descendants AS (
          SELECT id FROM comments WHERE parent_id = $1  -- 先找到它的第一级后代。
          UNION ALL                                     -- 表示合并结果但不去重
          SELECT child.id                                       -- 递归部分开始
          FROM comments AS child
          JOIN descendants ON child.parent_id = descendants.id  -- 递归部分结束
        )
        UPDATE comments
        SET soft_deleted_at = $2
        WHERE id IN (SELECT id FROM descendants)
          AND soft_deleted_at IS NULL
        SQL
      deleted_comment.id,
      deleted_comment.soft_deleted_at.not_nil!
    )

    # 这里不更新 topic 上的计数字段，因为那些字段由单独的 trigger 维护。
    TopicActivity.refresh(deleted_comment.comment_thread!) if result.rows_affected > 0
  end
end
