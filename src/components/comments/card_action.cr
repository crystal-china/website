class Comments::CardAction < BaseComponent
  needs comment : Comment
  needs order_by : String
  needs thread_expanded : Bool = false

  def render : Nil
    div(
      id: "comment-#{comment.id}-actions",
      class: "flex flex-1 flex-wrap items-center justify-end gap-x-4 gap-y-3"
    ) do
      if comment.parent_id.nil?
        mount(
          Comments::ThreadToggle,
          comment: comment,
          order_by: order_by,
          expanded: thread_expanded?,
          current_user: current_user
        )
      end

      if (me = current_user)
        render_comment_actions(me)
      end
    end
  end

  private def render_comment_actions(me : User) : Nil
    list_id = comment.root_id ? "comment-#{comment.root_id}-comments" : "comments"

    opts = {
      type:       "button",
      class:      "action-button action-button-accent",
      hx_target:  Comments::Dialog.comment_form_target,
      hx_swap:    "outerHTML",
      hx_disable: "this",
      script:     Comments::Dialog.open_comment_dialog,
    }

    div class: "flex shrink-0 flex-wrap items-center justify-end gap-2" do
      button(
        r("common.reply").t,
        opts,
        hx_get: Htmx::Comments::New.with(id: comment.id, order_by: order_by).path
      )

      if me.id == comment.user_id || me.admin?
        button(
          r("common.edit").t,
          opts,
          hx_get: Htmx::Comments::Edit.with(id: comment.id, order_by: order_by).path
        )

        if me.admin? || !CommentQuery.new.with_soft_deleted.parent_id(comment.id).any?
          confirmation = if comment.root_id.nil? && comment.descendants_count > 0
                           r(".confirm_delete_branch").t
                         else
                           r(".confirm_delete").t
                         end

          button(
            r("common.delete").t,
            type: "button",
            class: "action-button action-button-danger",
            hx_delete: Htmx::Comments::Delete.with(id: comment.id).path,
            hx_include: "##{list_id}-order-by",
            hx_target: "##{list_id}",
            hx_swap: "outerHTML swap:1s",
            hx_confirm: confirmation
          )
        end
      end
    end
  end
end
