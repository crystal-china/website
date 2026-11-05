class CreateComment < Comment::SaveOperation
  include CommentCreation

  permit_columns comment_thread_id, content

  before_save do
    prepare_new_comment if !id.value # 新建的时候

    validate_required user_id, content, comment_thread_id
  end

  after_save notify_comment_created, if: :new_record?
end

class ReplyToComment < Comment::SaveOperation
  include CommentCreation

  permit_columns parent_id, content

  before_save do
    if !id.value # 新建的时候
      prepare_new_comment

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
    end

    validate_required user_id, content, parent_id, comment_thread_id
  end

  after_save notify_comment_created, if: :new_record?
end
