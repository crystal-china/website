class Htmx::Comments::Restore < CommentAction
  param order_by : String = "desc"

  post "/htmx/comments/:id/restore" do
    me = current_user

    return head 401 if me.nil?

    SetCommentWithdrawal.run(
      comment_id: id.to_i64,
      actor: me,
      withdrawn: false
    ) do |operation, updated_comment|
      if (reason = operation.rejection_reason)
        return head 403 if reason.forbidden?
        return head 404 if reason.target_unavailable?
      end

      return head 500 if updated_comment.nil?
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
