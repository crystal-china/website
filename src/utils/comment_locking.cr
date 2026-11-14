module CommentLocking
  # 重新查询并返回已加锁的评论。
  # 删除或回复子评论时，先锁根评论，再锁这条子评论。
  # 删除或回复根评论时，只锁这条根评论。
  # 撤回和取消撤回也复用相同的加锁顺序；调用方负责开启事务。
  private def find_and_lock_comment(comment : Comment) : Comment
    if (root_id = comment.root_id)
      CommentQuery.new.id(root_id).for_update.first
      CommentQuery.new.id(comment.id).for_update.first
    else
      CommentQuery.new.id(comment.id).for_update.first
    end
  end
end
