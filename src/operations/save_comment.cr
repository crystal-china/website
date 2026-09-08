class SaveComment < Comment::SaveOperation
  permit_columns user_id, comment_thread_id, parent_id, content
  before_save validate_comment_thread_id_parent_id

  before_save do
    if !id.value # 新建的时候
      comment_thread_id.value.try do |comment_thread_id|
        comment_thread = CommentThreadQuery.find(comment_thread_id)
        path_for_doc = comment_thread.doc_id.try do |doc_id|
          DocQuery.find(doc_id).path_index
        end

        preferences.value = Comment::Preferences.from_json(
          {
            path_for_doc: path_for_doc,
          }.to_json
        )
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

        preferences.value = Comment::Preferences.from_json(
          {
            path_for_doc: nil,
          }.to_json
        )
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

  private def validate_comment_thread_id_parent_id
    if comment_thread_id.value.blank? == parent_id.value.blank?
      add_error :comment_thread_id_or_parent_id, "必须且只能有一个存在"
    end
  end
end
