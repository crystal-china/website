class Docs::RepliesMore < BaseComponent
  needs formatter : Tartrazine::Formatter
  needs pagination : {count: Int32 | Int64, replies: ReplyQuery, page: Lucky::Paginator?, url: String}
  needs page_number : Int32
  needs reply_id : Int64?

  def render
    pagination[:replies].each do |reply|
      id = reply.id

      article class: "box f-col #{reply.reply_id ?"ok" : ""}", id: fragment_id(id) do
        render_avatar_name_and_time(reply)

        hr style: "border: none; border-top: 1px solid darkgray;"

        raw markdown(reply.content)

        render_emoji_buttons_and_delete_button(reply)

        div class: "f-row justify-content:center", id: "#{fragment_id(id)}-replies" do
          if reply.replies_counter > 0
            a(
              hx_get: "/htmx/replies/#{id}?page=1",
              hx_target: "##{fragment_id(id)}-replies",
              hx_swap: "outerHTML",
              hx_include: "previous input[name='order_by']",
            ) do
              text "加载评论，共 #{reply.replies_counter} 条回复"
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
    div class: "f-row justify-content:space-between", style: "" do
      div class: "f-row" do
        img src: reply.user_avatar || asset("svgs/crystal-lang-icon.svg"), style: "height:24px;width:24px;"
        span reply.user_name
      end

      if reply_id == reply.id
        output(
          style: "display: inline-block; color: green;",
          script: "init transition my opacity to 0% over 3 seconds"
        ) do
          text "更新成功"
        end
      end

      div do
        a href: "##{fragment_id(reply.id)}" do
          span TimeInWords::Helpers(TimeInWords::I18n::ZH_CN).from(past_time: reply.created_at)
        end
        raw <<-HEREDOC
<chip style="margin-left: 10px; border-color: #ccc;">#{reply.preferences.floor} 楼</chip>
HEREDOC
      end
    end
  end

  private def render_emoji_buttons_and_delete_button(reply : Reply)
    me = current_user
    voted_types = if me.nil?
                    [] of String
                  else
                    VoteQuery.new.user_id(me.id).reply_id(reply.id).map &.vote_type
                  end

    div class: "f-row justify-content:space-between", style: "margin-bottom: 0px;" do
      div do
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
          class:      "chip",
          style:      "margin-right: 10px;",
          hx_target:  "div#reply_to_reply-form",
          hx_swap:    "outerHTML",
          hx_include: "[name='_csrf']",
          onclick:    "
const dialog = document.getElementById('edit_dialog');
dialog.showModal();
dialog.querySelector('textarea').focus();
",
        }

        div do
          if reply.reply_id.nil? # 只允许针对 doc 的评论进行回复
            a("回复", opts, hx_get: Htmx::Docs::Reply::New.with(id: reply.id, user_id: me.id).path)
          end

          if me.id == reply.user_id # 只允许编辑自己的回复
            a("编辑", opts, hx_get: Htmx::Docs::Reply::Edit.with(id: reply.id, user_id: me.id).path)

            if reply.replies_counter == 0 # 如果回复有了回复，就不再允许删除
              a(
                "删除",
                class: "border chip bad color",
                hx_delete: Htmx::Docs::Reply::Delete.with(id: reply.id, user_id: me.id).path,
                hx_target: "closest article.box",
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
      style: "
max-width: 100%;
width: 50em;
max-height: 100%;
height: 40em;
padding-bottom: 0;
"
    ) do
      div id: "reply_to_reply-form" do
      end
    end
  end
end
