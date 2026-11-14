class Htmx::Comments::Withdraw < CommentAction
  param order_by : String = "desc"

  post "/htmx/comments/:id/withdraw" do
    me = current_user

    return head 401 if me.nil?

    SetCommentWithdrawal.run(
      comment_id: id.to_i64,
      actor: me,
      withdrawn: true
    ) do |operation, _comment|
      return head 403 if operation.rejection_reason.try(&.forbidden?)
      return head 404 if operation.rejection_reason.try(&.target_unavailable?)
    end

    comment = CommentQuery.new.id(id).preload_user.preload_parent(&.preload_user).first

    component(
      ::Comments::CardBody,
      comment: comment,
      formatter: formatter,
      order_by: order_by,
    )
  end
end
