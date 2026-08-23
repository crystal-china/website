class Docs::RepliesMore < BaseComponent
  needs formatter : Tartrazine::Formatter
  needs pagination : {count: Int32 | Int64, replies: ReplyQuery, page: Lucky::Paginator?, url: String, order_by: String}
  needs page_number : Int32
  needs reply_id : Int64?

  def render
    pagination[:replies].each do |reply|
      article class: reply_card_classes(reply), id: "doc_reply-#{reply.id}" do
        render_avatar_name_and_time(reply)

        hr class: "my-2 border-0 border-t border-gray-300"

        div class: "prose-neutral max-w-none prose text-base leading-7" do
          raw markdown(reply.content)
        end

        render_emoji_buttons_and_delete_button(reply)

        div id: "doc_reply-#{reply.id}-replies" do
        end
      end
    end

    mount(
      Docs::RepliesMoreLink,
      pagination: pagination,
      page_number: page_number,
    )
  end

  private def render_avatar_name_and_time(reply)
    div class: "flex items-start justify-between gap-3" do
      div class: "flex min-w-0 items-center gap-3" do
        img src: reply.user_avatar || asset("svgs/crystal-lang-icon.svg"), class: "h-6 w-6 rounded-md border border-gray-300 bg-white object-cover p-0.5"
        span reply.user_name, class: "truncate text-xs font-semibold text-gray-900"
      end

      div class: "flex shrink-0 items-center gap-2" do
        a href: "#doc_reply-#{reply.id}" do
          span TimeInWords::Helpers(TimeInWords::I18n::ZH_CN).from(past_time: reply.created_at), class: "text-xs text-sky-700 underline decoration-dotted underline-offset-2"
        end
        span "#{reply.preferences.floor} 楼", class: "inline-flex items-center rounded-full border border-gray-300 bg-white px-2.5 py-0.5 text-xs font-medium text-gray-800"

        if reply_id == reply.id
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

  private def render_emoji_buttons_and_delete_button(reply : Reply)
    me = current_user
    has_direct_replies = ReplyQuery.new.reply_id(reply.id).any?
    voted_types = me ? VoteQuery.new.user_id(me.id).reply_id(reply.id).map(&.vote_type) : [] of String

    div class: "mt-2 flex flex-wrap items-end justify-between gap-x-4 gap-y-3" do
      div class: "flex min-w-0 flex-wrap items-center gap-2 text-sm" do
        mount(
          Shared::VoteButton,
          votes: Hash(String, Int32).from_json(reply.votes.to_json),
          reply_id: reply.id,
          current_user: me,
          voted_types: voted_types
        )
      end

      render_thread_toggle(reply)
      render_reply_actions(reply, me, has_direct_replies) unless me.nil?
    end
  end

  private def render_thread_toggle(reply : Reply)
    return unless reply.reply_id.nil? && reply.root_replies_count > 0

    link_class = "inline-flex h-8 items-center rounded-full border border-sky-200 bg-sky-50 px-3 text-sm font-medium text-sky-800 transition hover:border-sky-300 hover:bg-sky-100"

    div class: "shrink-0" do
      input type: "hidden", class: "reply-order-state", name: "order_by", value: pagination[:order_by]

      a(
        class: link_class,
        hx_get: "/htmx/replies/#{reply.id}?page=1",
        hx_include: "previous input",
        hx_target: "#doc_reply-#{reply.id}-replies",
        hx_swap: "outerHTML",
        flow_id: "doc_reply-#{reply.id}-load_thread",
        script: htmx_success <<-HEREDOC
add @hidden to me
remove @hidden from the next <a/>
HEREDOC
      ) do
        text "加载子评论，共 #{reply.root_replies_count} 条"
        mount Shared::Spinner, text: "正在读取评论...", width: "10px"
      end

      a(
        "折叠子评论",
        hidden: true,
        class: link_class,
        flow_id: "doc_reply-#{reply.id}-collapse_thread",
        script: <<-HYPER
on click
   put "" into #doc_reply-#{reply.id}-replies
  add @hidden to me
  remove @hidden from the previous <a/>
end
HYPER
      )
    end
  end

  private def render_reply_actions(reply : Reply, me : User, has_direct_replies : Bool)
    opts = {
      class:      "inline-flex h-6 shrink-0 items-center rounded-full border border-sky-600 px-3 text-sm font-medium whitespace-nowrap text-sky-700 hover:bg-sky-50",
      hx_target:  Docs::ReplyDialog.reply_form_target,
      hx_swap:    "outerHTML",
      hx_include: "[name='_csrf']",
      onclick:    Docs::ReplyDialog.open_reply_dialog_js,
    }

    div class: "flex shrink-0 flex-wrap items-center justify-end gap-2" do
      a("回复", opts, hx_get: Htmx::Docs::Reply::New.with(id: reply.id, user_id: me.id, order_by: pagination[:order_by]).path)

      if me.id == reply.user_id # 只允许编辑自己的回复
        a("编辑", opts, hx_get: Htmx::Docs::Reply::Edit.with(id: reply.id, user_id: me.id, order_by: pagination[:order_by]).path)

        if !has_direct_replies # 如果回复有了直接回复，就不再允许删除
          a(
            "删除",
            class: "inline-flex h-6 shrink-0 items-center rounded-full border border-red-400 px-3 text-sm font-medium whitespace-nowrap text-red-500 hover:bg-red-50",
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

  private def reply_card_classes(reply : Reply)
    classes = "mt-6 rounded-2xl border border-gray-300 px-7 py-2 shadow-sm"
    classes += reply.reply_id ? " ml-8 bg-green-100" : " bg-white"
    classes
  end
end
