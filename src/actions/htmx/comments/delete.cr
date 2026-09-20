class Htmx::Comments::Delete < CommentAction
  delete "/htmx/comments/:id" do
    me = current_user
    return head 401 if me.nil?

    status = 200
    comments_list_id = ""
    remaining_count = 0_i64

    AppDatabase.transaction do
      comment = CommentQuery.new.id(id).for_update.first

      next status = 403 if comment.user_id != me.id
      next status = 409 if comment.children_count > 0

      DeleteComment.delete!(comment)

      if (root_id = comment.root_id)
        comments_list_id = "comment-#{root_id}-comments"
        remaining_count = CommentQuery.new.root_id(root_id).select_count
      else
        comments_list_id = "comments"
        remaining_count = CommentQuery.new
          .comment_thread_id(comment.comment_thread_id)
          .parent_id.is_nil
          .select_count
      end
    end

    return head status unless status == 200

    plain_text <<-HTML
      <hx-partial
        hx-target="##{comments_list_id}-count"
      >
        共 #{remaining_count} 条回复
      </hx-partial>
    HTML
  end
end
