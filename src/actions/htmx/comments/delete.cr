class Htmx::Comments::Delete < CommentAction
  delete "/htmx/comments/:id" do
    me = current_user
    return head 401 if me.nil?

    comment = CommentQuery.find(id)

    return head 403 if comment.user_id != me.id
    return head 409 if comment.children_count > 0

    DeleteComment.delete!(comment)

    head 200
  end
end
