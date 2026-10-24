class Htmx::Comments::Restore < CommentAction
  param order_by : String = "desc"

  post "/htmx/comments/:id/restore" do
    me = current_user

    return head 401 if me.nil?

    AppDatabase.transaction do
      target = lock_comment(CommentQuery.find(id))

      return head 403 unless target.user_id == me.id || me.admin?
      return head 404 unless comment_available?(target)

      Comment::SaveOperation.update!(target, withdrawn: false)
    end

    query = CommentQuery.new.id(id).preload_user.preload_parent(&.preload_user)

    query.preload_votes(&.user_id(me.id))

    component(
      ::Comments::CardBody,
      comment: query.first,
      formatter: formatter,
      order_by: order_by,
      preserve_thread_toggle: true,
      current_user: me
    )
  end
end
