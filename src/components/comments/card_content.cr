class Comments::CardContent < BaseComponent
  needs formatter : Tartrazine::Formatter
  needs comment : Comment
  needs show_update_success : Bool = false

  def render : Nil
    div id: "comment-#{comment.id}-content" do
      render_avatar_name_and_time

      hr class: "my-2 border-0 border-t border-gray-300"

      div class: "prose-neutral max-w-none prose text-base leading-7" do
        raw(comment.content_html || user_markdown(comment.content))
      end
    end
  end

  private def render_avatar_name_and_time : Nil
    user = comment.user

    header class: "flex flex-wrap items-start justify-between gap-3 sm:flex-nowrap" do
      div class: "flex min-w-0 items-center gap-3" do
        mount(
          Shared::Avatar,
          user: user,
          classes: "h-6 w-6 rounded-md border border-gray-300 text-xs"
        )
        div class: "min-w-0 text-xs" do
          mount Shared::UserName, user: user, stacked: true
        end
      end

      render_parent_comment_hint

      div class: "flex shrink-0 items-center gap-2 text-xs leading-none" do
        a(
          href: "#comment-#{comment.id}",
          class: "inline-flex items-center text-sky-700 underline decoration-dotted underline-offset-2"
        ) do
          local_time(
            comment.created_at,
            relative_time(comment.created_at)
          )
        end

        if (edited_at = comment.edited_at)
          local_time(
            edited_at,
            r(".edited_at").t(time: relative_time(edited_at)),
            class: "text-gray-500"
          )
        end

        span r(".floor").t(floor: comment.floor.to_s), class: "inline-flex items-center rounded-full border border-gray-300 bg-white px-2.5 py-0.5 font-medium text-gray-800"

        if show_update_success?
          output(
            class: "text-xs font-medium text-green-600",
            script: "init transition my opacity to 0% over 3 seconds"
          ) do
            text r(".updated").t
          end
        end
      end
    end
  end

  private def render_parent_comment_hint : Nil
    # 直接回复根评论时，缩进本身已经说明“这是针对这条顶级评论的回复”，不用再重复显示。
    # 但如果回复的是某条子评论，即使它是那条子评论的第一条回复，也应该显示“回复谁”。
    return unless (parent_id = comment.parent_id)
    return if comment.root_id == parent_id

    parent_comment = comment.parent

    div class: "order-3 min-w-0 basis-full self-center px-2 text-center text-xs font-medium text-green-700 sm:order-none sm:flex-1 sm:basis-auto" do
      if parent_comment && !parent_comment.soft_deleted?
        a(
          r(".reply_to").t(floor: parent_comment.floor.to_s, login_name: parent_comment.user.login_name),
          href: "#comment-#{parent_comment.id}",
          class: "inline-block truncate underline decoration-dotted underline-offset-2 hover:text-green-800"
        )
      else
        text r(".reply_to_deleted").t
      end
    end
  end
end
