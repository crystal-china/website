class Docs::RepliesMore < BaseComponent
  needs formatter : Tartrazine::Formatter
  needs pagination : {count: Int32 | Int64, replies: ReplyQuery, page: Lucky::Paginator?, url: String}
  needs page_number : Int32
  needs reply_id : Int64?

  def render
    pagination[:replies].each do |reply|
      id = reply.id

      card_classes = "mt-6 rounded-2xl border border-gray-300 bg-white px-7 py-5 shadow-sm"
      card_classes += " ml-8 border-sky-100 bg-sky-50/30" if reply.reply_id

      article class: card_classes, id: fragment_id(id) do
        render_avatar_name_and_time(reply)

        hr class: "my-5 border-0 border-t border-gray-300"

        div class: "prose-neutral max-w-none prose text-[1.15rem] leading-8" do
          raw markdown(reply.content)
        end

        render_emoji_buttons_and_delete_button(reply)

        div class: "mt-4 flex justify-center", id: "#{fragment_id(id)}-replies" do
          if reply.reply_id.nil? && reply.root_replies_count > 0
            a(
              class: "inline-flex items-center gap-2 rounded-full border border-gray-300 bg-gray-50 px-4 py-2 text-base font-medium text-gray-700 hover:border-gray-400 hover:bg-white",
              hx_get: "/htmx/replies/#{id}?page=1",
              hx_target: "##{fragment_id(id)}-replies",
              hx_swap: "outerHTML",
              hx_include: "previous input[name='order_by']",
            ) do
              text "加载评论，共 #{reply.root_replies_count} 条回复"
              mount Shared::Spinner, text: "正在读取评论...", width: "10px"
            end
          end
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
        img src: reply.user_avatar || asset("svgs/crystal-lang-icon.svg"), class: "h-12 w-12 rounded-md border border-gray-300 bg-white object-cover p-1"
        span reply.user_name, class: "truncate text-2xl font-semibold text-gray-900"
      end

      div class: "flex shrink-0 items-center gap-3" do
        a href: "##{fragment_id(reply.id)}" do
          span TimeInWords::Helpers(TimeInWords::I18n::ZH_CN).from(past_time: reply.created_at), class: "text-xl text-sky-700 underline decoration-dotted underline-offset-2"
        end
        span "#{reply.preferences.floor} 楼", class: "inline-flex items-center rounded-full border border-gray-300 bg-white px-4 py-1.5 text-xl font-medium text-gray-800"

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

    div class: "mt-6 flex items-center justify-between gap-4" do
      div class: "min-w-0 flex flex-wrap items-center gap-3 text-base" do
        mount(
          Shared::VoteButton,
          votes: Hash(String, Int32).from_json(reply.votes.to_json),
          reply_id: reply.id,
          current_user: me,
          voted_types: voted_types
        )
      end

      if !me.nil?
        opts = {
          class:      "inline-flex shrink-0 items-center whitespace-nowrap rounded-full border border-sky-600 px-4 py-1.5 text-lg font-medium text-sky-700 hover:bg-sky-50",
          hx_target:  "div#reply_to_reply-form",
          hx_swap:    "outerHTML",
          hx_include: "[name='_csrf']",
          onclick:    "
const dialog = document.getElementById('edit_dialog');
dialog.showModal();
dialog.querySelector('textarea').focus();
",
        }

        div class: "flex shrink-0 flex-wrap items-center justify-end gap-3" do
          a("回复", opts, hx_get: Htmx::Docs::Reply::New.with(id: reply.id, user_id: me.id).path)
          
          if me.id == reply.user_id # 只允许编辑自己的回复
            a("编辑", opts, hx_get: Htmx::Docs::Reply::Edit.with(id: reply.id, user_id: me.id).path)

            if !has_direct_replies # 如果回复有了直接回复，就不再允许删除
              a(
                "删除",
                class: "inline-flex shrink-0 items-center whitespace-nowrap rounded-full border border-red-400 px-4 py-1.5 text-lg font-medium text-red-500 hover:bg-red-50",
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
