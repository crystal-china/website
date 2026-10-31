class Comments::CardContent < BaseComponent
  needs formatter : Tartrazine::Formatter
  needs comment : Comment
  needs show_update_success : Bool = false

  def render : Nil
    div id: "comment-#{comment.id}-content" do
      render_comment_header = ->(show_expand : Bool) { render_avatar_name_and_time(show_expand) }
      render_full_comment_body = -> do
        div class: "prose-neutral max-w-none prose text-base leading-7" do
          if comment.withdrawn?
            para r("common.comment_withdrawn").t, class: "text-sm text-gray-500"
          else
            raw(comment.content_html || user_markdown(comment.content))
          end
        end
      end

      mount(
        Shared::CommentPreview,
        content: comment.withdrawn? ? r("common.comment_withdrawn").t : comment.content,
        render_header: render_comment_header,
        render_body: render_full_comment_body
      )
    end
  end

  private def render_avatar_name_and_time(show_expand : Bool) : Nil
    user = comment.user
    fade_comment_update_success_message_script = "init transition my opacity to 0% over 3 seconds"

    header class: "mb-2 flex flex-wrap items-center justify-between gap-3 sm:flex-nowrap" do
      div class: "flex min-w-0 items-center gap-3" do
        mount(
          Shared::Avatar,
          user: user,
          classes: "h-6 w-6 rounded-md border border-gray-300 text-xs"
        )
        div class: "min-w-0 text-xs" do
          mount(
            Shared::UserName,
            user: user
          )
        end
      end

      div class: "flex min-w-fit flex-1 flex-wrap items-center justify-center gap-2" do
        if show_expand
          span(
            r("shared.comment_preview.expand_content").t,
            class: "comment-preview-expand-label text-sm font-medium whitespace-nowrap text-sky-700"
          )
        end

        render_parent_comment_hint
      end

      div class: "ml-auto flex shrink-0 items-center gap-2 text-xs leading-none" do
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

        span(
          r(".floor").t(floor: comment.floor.to_s),
          class: "inline-flex items-center rounded-full border border-gray-300 bg-white px-2.5 py-0.5 font-medium text-gray-800"
        )

        if show_update_success?
          output(
            class: "text-xs font-medium text-green-600",
            script: fade_comment_update_success_message_script
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

    div class: "min-w-0 text-center text-xs font-medium text-green-700" do
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
