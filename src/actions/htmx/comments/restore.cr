class Htmx::Comments::Restore < CommentAction
  param order_by : String = "desc"

  post "/htmx/comments/:id/restore" do
    me = current_user

    return head 401 if me.nil?

    SetCommentWithdrawal.run(
      comment_id: id.to_i64,
      actor: me,
      withdrawn: false
    ) do |operation, _comment|
      return head 403 if operation.rejection_reason.try(&.forbidden?)
      return head 404 if operation.rejection_reason.try(&.target_unavailable?)
    end

    query = CommentQuery.new.id(id).preload_user.preload_parent(&.preload_user)

    query.preload_votes(&.user_id(me.id))

    component(
      ::Comments::CardBody,
      comment: query.first,
      formatter: formatter,
      order_by: order_by,
    )
  end
end
