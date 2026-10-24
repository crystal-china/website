class Comments::CardControls < BaseComponent
  needs comment : Comment
  needs order_by : String
  # 子评论按钮是展开还是关闭。
  needs reply_expanded : Bool = false
  # 是否保留现有展开／折叠按钮，不重新设置它的状态。
  needs preserve_thread_toggle : Bool = false

  def render : Nil
    div(
      id: "comment-#{comment.id}-controls",
      class: "flex flex-1 flex-wrap items-center justify-end gap-x-4 gap-y-3"
    ) do
      if comment.parent_id.nil?
        if preserve_thread_toggle?
          # 保留展开／折叠按钮当前状态，与卡片内保留的回复列表一致。
          div id: "comment-#{comment.id}-thread-toggle", hx_preserve: "true"
        else
          mount(
            Comments::ThreadToggle,
            comment: comment,
            order_by: order_by,
            expanded: reply_expanded?,
            current_user: current_user
          )
        end
      end

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

    list_id = comment.root_id ? "comment-#{comment.root_id}-comments" : "comments"

    button(
      r("common.restore").t,
      type: "button",
      class: "action-button action-button-accent",
      hx_post: Htmx::Comments::Restore.with(id: comment.id).path,
      hx_include: "##{list_id}-order-by",
      hx_target: "#comment-#{comment.id}-body",
      # HTMX 4 的 settle 过渡会先覆盖 hx-preserve，跳过过渡才能保留回复 DOM。
      hx_swap: "outerHTML settle:0"
    )

    if comment.deletable?
      mount(
        Comments::DeleteOrWithdraw,
        comment: comment,
        current_user: me
      )
    end
  end

  private def render_comment_actions(me : User) : Nil
    opts = {
      type:       "button",
      class:      "action-button action-button-accent",
      hx_target:  Comments::Dialog.comment_form_target,
      hx_swap:    "outerHTML",
      hx_disable: "this",
      script:     Comments::Dialog.open_comment_dialog,
    }

    div class: "flex max-w-full shrink-0 flex-wrap items-center justify-end gap-2" do
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

        mount(
          Comments::DeleteOrWithdraw,
          comment: comment,
          current_user: me
        )
      end
    end
  end
end
