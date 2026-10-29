class Htmx::Comments::Edit < CommentAction
  param order_by : String?

  get "/htmx/comments/edit/:id" do
    me = current_user
    return head 401 if me.nil?

    comment = CommentQuery.find(id)
    return head 404 unless comment_available?(comment)

    return head 403 unless comment.user_id == me.id || me.admin?
    return head 409 if comment.withdrawn?

    component(
      ::Comments::Form,
      content: comment.content,
      html_id: "comment",
      order_by: order_by,
      comment_id: id.to_i64
    )
  end
end
