class Comments::ListMore < BaseComponent
  needs formatter : Tartrazine::Formatter
  needs pagination : {count: Int32 | Int64, comments: CommentQuery, page: Lucky::Paginator?, url: String, order_by: String}
  needs page_number : Int32
  needs comment_id : Int64?

  def render
    comments = pagination[:comments].results

    comments.each do |comment|
      article class: comment_card_classes(comment), id: "comment-#{comment.id}" do
        render_avatar_name_and_time(comment)

        hr class: "my-2 border-0 border-t border-gray-300"

        div class: "prose-neutral max-w-none prose text-base leading-7" do
          raw user_markdown(comment.content)
        end

        render_emoji_buttons_and_delete_button(comment)

        div id: "comment-#{comment.id}-comments" do
        end
      end
    end

    mount(
      Comments::LoadMoreButton,
      pagination: pagination,
      page_number: page_number,
    )
  end

  private def render_avatar_name_and_time(comment : Comment)
    user = comment.user

    header class: "flex flex-wrap items-start justify-between gap-3 sm:flex-nowrap" do
      div class: "flex min-w-0 items-center gap-3" do
        img src: user.avatar || asset("svgs/crystal-lang-icon.svg"), class: "h-6 w-6 rounded-md border border-gray-300 bg-white object-cover p-0.5"
        span user.name, class: "truncate text-xs font-semibold text-gray-900"
      end

      render_parent_comment_hint(comment)

      div class: "flex shrink-0 items-center gap-2 text-xs leading-none" do
        a(
          TimeInWords::Helpers(TimeInWords::I18n::ZH_CN).from(past_time: comment.created_at),
          href: "#comment-#{comment.id}",
          class: "inline-flex items-center text-sky-700 underline decoration-dotted underline-offset-2"
        )

        if (edited_at = comment.edited_at)
          span(
            "已编辑于 #{TimeInWords::Helpers(TimeInWords::I18n::ZH_CN).from(past_time: edited_at)}",
            class: "text-gray-500",
            title: edited_at.to_local.to_s("%Y-%m-%d %H:%M:%S")
          )
        end

        span "#{comment.floor} 楼", class: "inline-flex items-center rounded-full border border-gray-300 bg-white px-2.5 py-0.5 font-medium text-gray-800"

        if comment_id == comment.id
          output(
            class: "text-xs font-medium text-green-600",
            script: "init transition my opacity to 0% over 3 seconds"
          ) do
            text "更新成功"
          end
        end
      end
    end
  end

  private def render_parent_comment_hint(comment : Comment)
    return unless (parent_comment = comment.parent)
    # 直接回复根评论时，缩进本身已经说明“这是针对这条顶级评论的回复”，不用再重复显示。
    # 但如果回复的是某条子评论，即使它是那条子评论的第一条回复，也应该显示“回复谁”。
    return if comment.root_id == parent_comment.id

    div class: "order-3 min-w-0 basis-full self-center px-2 text-center text-xs font-medium text-green-700 sm:order-none sm:flex-1 sm:basis-auto" do
      a(
        "回复 #{parent_comment.floor} 楼 @#{parent_comment.user.name}",
        href: "#comment-#{parent_comment.id}",
        class: "inline-block truncate underline decoration-dotted underline-offset-2 hover:text-green-800"
      )
    end
  end

  private def render_emoji_buttons_and_delete_button(comment : Comment)
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
          order_by: pagination[:order_by],
          current_user: current_user
        )
      end
      render_comment_actions(comment, me) unless me.nil?
    end
  end

  private def render_comment_actions(comment : Comment, me : User)
    opts = {
      type:       "button",
      class:      "inline-flex h-6 shrink-0 items-center rounded-full border border-sky-600 px-3 text-sm font-medium whitespace-nowrap text-sky-700 hover:bg-sky-50",
      hx_target:  Comments::Dialog.comment_form_target,
      hx_swap:    "outerHTML",
      hx_disable: "this",
      script:     Comments::Dialog.open_comment_dialog,
    }

    div class: "flex shrink-0 flex-wrap items-center justify-end gap-2" do
      button("回复", opts, hx_get: Htmx::Comments::New.with(id: comment.id, order_by: pagination[:order_by]).path)

      if me.id == comment.user_id # 只允许编辑自己的回复
        button("编辑", opts, hx_get: Htmx::Comments::Edit.with(id: comment.id, order_by: pagination[:order_by]).path)

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

  private def comment_card_classes(comment : Comment)
    classes = "mt-6 rounded-2xl border border-gray-300 px-4 py-2 shadow-sm sm:px-7"
    classes += comment.parent_id ? " bg-green-100 sm:ml-8" : " bg-white"
    classes
  end
end
