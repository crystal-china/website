class Comments::CardContent < BaseComponent
  needs formatter : Tartrazine::Formatter
  needs comment : Comment
  needs show_update_success : Bool = false

  def render
    div id: "comment-#{comment.id}-content" do
      render_avatar_name_and_time

      hr class: "my-2 border-0 border-t border-gray-300"

      div class: "prose-neutral max-w-none prose text-base leading-7" do
        raw user_markdown(comment.content)
      end
    end
  end

  private def render_avatar_name_and_time
    user = comment.user

    header class: "flex flex-wrap items-start justify-between gap-3 sm:flex-nowrap" do
      div class: "flex min-w-0 items-center gap-3" do
        img src: user.avatar || asset("svgs/crystal-lang-icon.svg"), class: "h-6 w-6 rounded-md border border-gray-300 bg-white object-cover p-0.5"
        span user.name, class: "truncate text-xs font-semibold text-gray-900"
      end

      render_parent_comment_hint

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

        if show_update_success?
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

  private def render_parent_comment_hint
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
end
