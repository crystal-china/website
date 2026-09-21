class Comments::Card < BaseComponent
  needs formatter : Tartrazine::Formatter
  needs comment : Comment
  needs order_by : String
  needs show_update_success : Bool = false

  def render
    article class: comment_card_classes, id: "comment-#{comment.id}" do
      mount(
        Comments::CardContent,
        formatter: formatter,
        comment: comment,
        show_update_success: show_update_success?,
        current_user: current_user
      )

      render_emoji_buttons_and_delete_button

      div id: "comment-#{comment.id}-comments" do
      end
    end
  end

  private def render_emoji_buttons_and_delete_button
    me = current_user
    voted_types = me ? comment.votes.map(&.vote_type) : [] of String

    footer class: "mt-2 flex flex-wrap items-end justify-between gap-x-4 gap-y-3" do
      div class: "flex min-w-0 flex-wrap items-center gap-2 text-sm" do
        mount(
          Shared::VoteButton,
          vote_counts: Hash(String, Int32).from_json(comment.vote_counts.to_json),
          comment_id: comment.id,
          current_user: me,
          voted_types: voted_types
        )
      end

      if comment.parent_id.nil?
        mount(
          Comments::ThreadToggle,
          comment: comment,
          order_by: order_by,
          current_user: current_user
        )
      end
      render_comment_actions(me) unless me.nil?
    end
  end

  private def render_comment_actions(me : User)
    opts = {
      type:       "button",
      class:      "inline-flex h-6 shrink-0 items-center rounded-full border border-sky-600 px-3 text-sm font-medium whitespace-nowrap text-sky-700 hover:bg-sky-50",
      hx_target:  Comments::Dialog.comment_form_target,
      hx_swap:    "outerHTML",
      hx_disable: "this",
      script:     Comments::Dialog.open_comment_dialog,
    }

    div class: "flex shrink-0 flex-wrap items-center justify-end gap-2" do
      button("回复", opts, hx_get: Htmx::Comments::New.with(id: comment.id, order_by: order_by).path)

      if me.id == comment.user_id # 只允许编辑自己的回复
        button("编辑", opts, hx_get: Htmx::Comments::Edit.with(id: comment.id, order_by: order_by).path)

        if comment.children_count == 0 # 如果回复有了直接回复，就不再允许删除
          button(
            "删除",
            type: "button",
            class: "inline-flex h-6 shrink-0 items-center rounded-full border border-red-400 px-3 text-sm font-medium whitespace-nowrap text-red-500 hover:bg-red-50",
            hx_delete: Htmx::Comments::Delete.with(id: comment.id).path,
            hx_confirm: "删除这条回复？"
          )
        end
      end
    end
  end

  private def comment_card_classes
    classes = "mt-6 rounded-2xl border border-gray-300 px-4 py-2 shadow-sm sm:px-7"
    classes += comment.parent_id ? " bg-green-100 sm:ml-8" : " bg-white"
    classes
  end
end
