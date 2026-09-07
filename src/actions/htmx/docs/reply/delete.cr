class Htmx::Docs::Reply::Delete < DocAction
  param user_id : Int64

  delete "/htmx/docs/reply/:id" do
    me = current_user
    return head 401 if me.nil?
    return head 403 if user_id != me.id

    comment = CommentQuery.find(id)

    return head 403 if comment.user_id != me.id
    return head 409 if comment.children_count > 0

    DeleteComment.delete!(comment)

    head 200
  end
end
