class Docs::ReplyToDocForm < BaseComponent
  needs content : String = ""
  needs html_id : String = "tab"
  needs doc_path : String?
  needs reply_id : Int64?
  needs target_reply_id : Int64? = nil

  def render
    mount(
      Docs::Form,
      content: content,
      doc_path: doc_path,
      reply_id: reply_id,
      current_user: current_user,
      html_id: html_id
    ) do
      me = current_user
      text = "回复"

      opts = {
        style:      "margin-right: 25px; margin-left: 10px;",
        hx_target:  "div#replies",
        hx_include: "[name='_csrf'],next textarea",
        script:     "on click set value of next <textarea/> to ''",
        hx_post:    Htmx::Docs::Reply::CreateOrUpdate.path_without_query_params,
        onclick:    "document.getElementById('edit_dialog').close();",
        flow_id:    "#{html_id}-do_reply",
      }

      if me.nil?
        opts = opts.merge(disabled: "")
      else
        if !reply_id.nil?
          # 一定是针对 reply 的操作，这里包含三种情况
          # - 为评论新增评论
          # - 编辑评论
          # - 编辑评论的评论。
          if content.blank?
            # 为评论新增评论
            opts = opts.merge(
              hx_vals: %({"user_id": #{me.id}, "id": #{reply_id}, "op": "new"}),
              hx_target: "#doc_reply-#{target_reply_id || reply_id}-replies",
              hx_swap: "outerHTML"
            )
          else
            # 这里覆盖两种编辑的情况
            reply = ReplyQuery.find(reply_id.not_nil!)

            if !(id = reply.reply_id).nil?
              # 如果修改评论的评论，htmx target 直接覆盖子评论列表
              opts = opts.merge(
                hx_target: "#doc_reply-#{target_reply_id || id}-replies"
              )
            end

            opts = opts.merge(
              hx_vals: %({"user_id": #{me.id}, "id": #{reply_id}, "op": "edit"}),
              hx_swap: "outerHTML",
              onclick: "scrollToElementById('doc_reply-#{reply_id}')",
            )
            text = "修改"
          end
        else
          # 为 doc 新建评论
          opts = opts.merge(
            hx_vals: %({"user_id": #{me.id}, "doc_path": "#{doc_path}"}),
          )
        end
      end

      span style: "float:right;" do
        if !reply_id.nil? && !me.nil?
          button(
            "取消",
            onclick: "document.getElementById('edit_dialog').close();"
          )
        end
        strong do
          button(text, opts)
        end
      end
    end
  end
end
