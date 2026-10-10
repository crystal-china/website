class SaveComment < Comment::SaveOperation
  permit_columns user_id, comment_thread_id, parent_id, content

  before_save do
    if !id.value # 新建的时候
      if parent_id.value && comment_thread_id.value
        add_error :comment_thread_id_or_parent_id, "不能同时指定评论区和父评论"
      end

      parent_id.value.try do |parent_id|
        parent_comment = CommentQuery.find(parent_id)
        comment_thread_id.value = parent_comment.comment_thread_id
        #  - 如果父评论已经知道它属于哪个根评论, 用父评论的 root_id
        #    即：至少是第三级评论，第一级 doc，第二级 root comment, 第三级才是父评论

        # - 如果父评论没有 root_id, 说明父评论自己就是根评论, 因此使用它的 id
        #   此时父评论就是上面的第二级 root comment
        thread_root_id = parent_comment.root_id || parent_comment.id
        root_id.value = thread_root_id
      end

      vote_counts.value = Comment::VoteCounts.from_json(
        {
          👍:  0,
          👎:  0,
          😄:  0,
          ❤️: 0,
          🎉:  0,
          😕:  0,
          👀️: 0,
        }.to_json
      )
    end

    validate_required user_id, content, comment_thread_id
  end

  # 新增才发送回复通知。
  after_save do |comment|
    NotificationDelivery.comment_created(comment) if new_record?
  end
end
