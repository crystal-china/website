class Htmx::Comments::Delete < CommentAction
  delete "/htmx/comments/:id" do
    me = current_user
    return head 401 if me.nil?

    status = 200
    AppDatabase.transaction do
      comment = CommentQuery.new.id(id).for_update.first

      next status = 403 if comment.user_id != me.id
      next status = 409 if comment.children_count > 0

      DeleteComment.delete!(comment)
    end

    head status
  end
end
