class Comments::DeleteOrWithdraw < BaseComponent
  needs comment : Comment

  def render : Nil
    me = current_user

    return if me.nil? || (me.id != comment.user_id && !me.admin?)

    span id: "comment-#{comment.id}-delete-or-withdraw" do
      list_id = comment.root_id ? "comment-#{comment.root_id}-comments" : "comments"
      delete_target_id = comment.root_id ? "comment-#{comment.root_id}-thread" : "comments"
      hx_swap = "outerHTML"
      opts = {
        type:       "button",
        class:      "action-button action-button-danger",
        hx_include: "##{list_id}-order-by",
        hx_swap:    "#{hx_swap} swap:1s",
      }

      if comment.deletable?
        button(
          r("common.delete").t,
          opts,
          hx_delete: Htmx::Comments::Delete.with(id: comment.id).path,
          hx_target: "##{delete_target_id}",
          hx_confirm: r(".confirm_delete").t
        )
      elsif !comment.withdrawn?
        button(
          r(".withdraw").t,
          opts,
          hx_post: Htmx::Comments::Withdraw.with(id: comment.id).path,
          hx_target: "#comment-#{comment.id}-body",
          hx_confirm: r(".confirm_withdraw").t
        )
      end
    end
  end
end
