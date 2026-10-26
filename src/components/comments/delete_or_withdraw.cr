class Comments::DeleteOrWithdraw < BaseComponent
  needs comment : Comment

  def render : Nil
    me = current_user

    return if me.nil? || (me.id != comment.user_id && !me.admin?)

    span(
      id: "comment-#{comment.id}-delete-or-withdraw",
      class: "inline-flex flex-wrap items-center gap-1"
    ) do
      list_id = comment.root_id ? "comment-#{comment.root_id}-replies-list" : "comments"
      delete_target_id = comment.root_id ? "comment-#{comment.root_id}-replies" : "comments"
      hx_swap = "outerHTML"
      opts = {
        type:       "button",
        class:      "comment-action-button",
        hx_include: "##{list_id}-order-by",
        hx_swap:    "#{hx_swap} swap:1s",
      }

      if !comment.withdrawn?
        button(
          opts,
          title: r(".withdraw").t,
          hx_post: Htmx::Comments::Withdraw.with(id: comment.id).path,
          hx_target: "#comment-#{comment.id}-body"
        ) do
          img(
            src: asset("svgs/comments/withdraw.svg"),
            alt: r(".withdraw").t,
            class: "comment-action-icon"
          )
        end
      end

      if comment.deletable?
        button(
          opts,
          title: r("common.delete").t,
          class: "comment-action-button comment-action-danger",
          hx_delete: Htmx::Comments::Delete.with(id: comment.id).path,
          hx_target: "##{delete_target_id}",
          hx_confirm: r(".confirm_delete").t
        ) do
          img(
            src: asset("svgs/notifications/delete.svg"),
            alt: r("common.delete").t,
            class: "comment-action-icon"
          )
        end
      end
    end
  end
end
