class Comments::CardControls < BaseComponent
  needs comment : Comment
  needs order_by : String

  def render : Nil
    div(
      id: "comment-#{comment.id}-controls",
      class: "flex flex-1 flex-wrap items-center justify-end gap-1"
    ) do
      if (me = current_user)
        if comment.withdrawn?
          render_withdrawn_actions(me)
        else
          render_comment_actions(me)
        end
      end
    end
  end

  private def render_withdrawn_actions(me : User) : Nil
    return unless me.id == comment.user_id || me.admin?

    list_id = comment.root_id ? "comment-#{comment.root_id}-replies-list" : "comments"

    button(
      type: "button",
      title: r("common.restore").t,
      class: "icon-action-button icon-action-primary",
      hx_post: Htmx::Comments::Restore.with(id: comment.id).path,
      hx_include: "##{list_id}-order-by",
      hx_target: "#comment-#{comment.id}-body",
      hx_swap: "outerHTML swap:1s"
    ) do
      img(
        src: asset("svgs/comments/restore.svg"),
        alt: r("common.restore").t,
        class: "icon-action-image"
      )
    end

    if comment.deletable?
      mount(
        Comments::DeleteOrWithdraw,
        comment: comment,
      )
    end
  end

  private def render_comment_actions(me : User) : Nil
    opts = {
      type:       "button",
      class:      "icon-action-button",
      hx_target:  Comments::Dialog.comment_form_target,
      hx_swap:    "outerHTML",
      hx_disable: "this",
      script:     Comments::Dialog.open_comment_dialog,
    }

    div class: "flex max-w-full flex-wrap items-center justify-end gap-1" do
      button(
        opts,
        title: r("common.reply").t,
        class: "icon-action-button icon-action-primary",
        hx_get: Htmx::Comments::New.with(id: comment.id, order_by: order_by).path
      ) do
        img(
          src: asset("svgs/notifications/reply.svg"),
          alt: r("common.reply").t,
          class: "icon-action-image"
        )
      end

      if me.id == comment.user_id || me.admin?
        button(
          opts,
          title: r("common.edit").t,
          hx_get: Htmx::Comments::Edit.with(id: comment.id, order_by: order_by).path
        ) do
          img(
            src: asset("svgs/notifications/edit.svg"),
            alt: r("common.edit").t,
            class: "icon-action-image"
          )
        end

        mount(
          Comments::DeleteOrWithdraw,
          comment: comment,
        )
      end
    end
  end
end
