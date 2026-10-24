class Comments::DeleteOrWithdraw < BaseComponent
  needs comment : Comment

  def render : Nil
    me = current_user

    return if me.nil? || (me.id != comment.user_id && !me.admin?)

    span id: "comment-#{comment.id}-delete-or-withdraw" do
      list_id = comment.root_id ? "comment-#{comment.root_id}-comments" : "comments"
      hx_swap = "outerHTML"
      opts = {
        type:       "button",
        class:      "action-button action-button-danger",
        hx_include: "##{list_id}-order-by",
      }

      if comment.deletable?
        button(
          r("common.delete").t,
          opts,
          hx_delete: Htmx::Comments::Delete.with(id: comment.id).path,
          hx_target: "##{list_id}",
          hx_swap: "#{hx_swap} swap:1s",
          hx_confirm: r(".confirm_delete").t
        )
      elsif !comment.withdrawn?
        button(
          r(".withdraw").t,
          opts,
          hx_post: Htmx::Comments::Withdraw.with(id: comment.id).path,
          hx_target: "#comment-#{comment.id}-body",
          # TODO: 升级到包含 htmx #4056 修复的正式版本后，移除 settle:0，统一用 swap:1s。
          hx_swap: "#{hx_swap} settle:0",
          hx_confirm: r(".confirm_withdraw").t
        )
      end
    end
  end
end
