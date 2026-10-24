class Htmx::Comments::Withdraw < CommentAction
  param order_by : String = "desc"

  post "/htmx/comments/:id/withdraw" do
    me = current_user

    return head 401 if me.nil?

    AppDatabase.transaction do
      target = lock_comment(CommentQuery.find(id))

      return head 403 unless target.user_id == me.id || me.admin?
      return head 404 unless comment_available?(target)

      Comment::SaveOperation.update!(target, withdrawn: true)
    end

    comment = CommentQuery.new.id(id).preload_user.preload_parent(&.preload_user).first

    component(
      ::Comments::CardBody,
      comment: comment,
      formatter: formatter,
      order_by: order_by,
      current_user: me
    )
  end
end
