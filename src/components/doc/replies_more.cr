class Docs::RepliesMore < BaseComponent
  needs formatter : Tartrazine::Formatter
  needs pagination : {count: Int32 | Int64, replies: ReplyQuery, page: Lucky::Paginator?, url: String}
  needs page_number : Int32
  needs reply_id : Int64?

  def render
    pagination[:replies].each do |reply|
      id = reply.id

      card_classes = "mt-6 rounded-2xl border border-gray-300 px-7 pt-5 pb-3 shadow-sm"
      card_classes += reply.reply_id ? " ml-8 bg-green-100" : " bg-white"

      article class: card_classes, id: fragment_id(id) do
        render_avatar_name_and_time(reply)

        hr class: "my-5 border-0 border-t border-gray-300"

        div class: "prose-neutral max-w-none prose text-base leading-7" do
          raw markdown(reply.content)
        end

        render_emoji_buttons_and_delete_button(reply)

        div id: "#{fragment_id(id)}-replies-shell", class: "replies-shell" do
        end
      end
    end

    mount(
      Docs::RepliesMoreLink,
      pagination: pagination,
      page_number: page_number,
    )

    edit_dialog
  end

  private def render_avatar_name_and_time(reply)
    div class: "flex items-start justify-between gap-4" do
      div class: "flex min-w-0 items-center gap-4" do
        img src: reply.user_avatar || asset("svgs/crystal-lang-icon.svg"), class: "h-9 w-9 rounded-md border border-gray-300 bg-white object-cover p-1"
        span reply.user_name, class: "truncate text-base font-semibold text-gray-900"
      end

      div class: "flex shrink-0 items-center gap-3" do
        a href: "##{fragment_id(reply.id)}" do
          span TimeInWords::Helpers(TimeInWords::I18n::ZH_CN).from(past_time: reply.created_at), class: "text-base text-sky-700 underline decoration-dotted underline-offset-2"
        end
        span "#{reply.preferences.floor} 楼", class: "inline-flex items-center rounded-full border border-gray-300 bg-white px-4 py-1.5 text-base font-medium text-gray-800"

        if reply_id == reply.id
          output(
            class: "text-base font-medium text-green-600",
            script: "init transition my opacity to 0% over 3 seconds"
          ) do
            text "更新成功"
          end
        end
      end
    end
  end

  private def render_emoji_buttons_and_delete_button(reply : Reply)
    me = current_user
    has_direct_replies = ReplyQuery.new.reply_id(reply.id).any?
    voted_types = if me.nil?
                    [] of String
                  else
                    VoteQuery.new.user_id(me.id).reply_id(reply.id).map &.vote_type
                  end

    div class: "mt-4 flex flex-wrap items-end justify-between gap-x-4 gap-y-3" do
      div class: "min-w-0 flex flex-wrap items-center gap-2 text-sm" do
        mount(
          Shared::VoteButton,
          votes: Hash(String, Int32).from_json(reply.votes.to_json),
          reply_id: reply.id,
          current_user: me,
          voted_types: voted_types
        )
      end

      if reply.reply_id.nil? && reply.root_replies_count > 0
        div class: "reply-toggle shrink-0" do
          a(
            class: "reply-expand inline-flex h-6 items-center px-2 text-sm font-medium text-gray-700 underline decoration-dotted underline-offset-2 hover:text-gray-900",
            hx_get: "/htmx/replies/#{reply.id}?page=1",
            hx_target: "##{fragment_id(reply.id)}-replies-shell",
            hx_swap: "innerHTML",
            hx_include: "previous input[name='order_by']",
          ) do
            text "加载子评论，共 #{reply.root_replies_count} 条"
            mount Shared::Spinner, text: "正在读取评论...", width: "10px"
          end

          a(
            "折叠子评论",
            class: "reply-collapse inline-flex h-6 items-center px-2 text-sm font-medium text-gray-700 underline decoration-dotted underline-offset-2 hover:text-gray-900",
            hx_get: Htmx::Null.path_without_query_params,
            hx_target: "##{fragment_id(reply.id)}-replies",
            hx_swap: "delete",
          )
        end
      end

      if !me.nil?
        opts = {
          class:      "inline-flex h-6 shrink-0 items-center whitespace-nowrap rounded-full border border-sky-600 px-3 text-sm font-medium text-sky-700 hover:bg-sky-50",
          hx_target:  "div#reply_to_reply-form",
          hx_swap:    "outerHTML",
          hx_include: "[name='_csrf']",
          onclick:    "
const dialog = document.getElementById('edit_dialog');
dialog.showModal();
dialog.querySelector('textarea').focus();
",
        }

        div class: "flex shrink-0 flex-wrap items-center justify-end gap-2" do
          a("回复", opts, hx_get: Htmx::Docs::Reply::New.with(id: reply.id, user_id: me.id).path)
          
          if me.id == reply.user_id # 只允许编辑自己的回复
            a("编辑", opts, hx_get: Htmx::Docs::Reply::Edit.with(id: reply.id, user_id: me.id).path)

            if !has_direct_replies # 如果回复有了直接回复，就不再允许删除
              a(
                "删除",
                class: "inline-flex h-6 shrink-0 items-center whitespace-nowrap rounded-full border border-red-400 px-3 text-sm font-medium text-red-500 hover:bg-red-50",
                hx_delete: Htmx::Docs::Reply::Delete.with(id: reply.id, user_id: me.id).path,
                hx_target: "closest article",
                hx_swap: "outerHTML swap:1s",
                hx_include: "[name='_csrf']",
                hx_confirm: "删除这条回复？"
              )
            end
          end
        end
      end
    end
  end

  private def fragment_id(reply_id)
    "doc_reply-#{reply_id}"
  end

  private def edit_dialog
    dialog(
      id: "edit_dialog",
      class: "h-[40em] max-h-full w-[50em] max-w-full pb-0"
    ) do
      div id: "reply_to_reply-form" do
      end
    end
  end
end
