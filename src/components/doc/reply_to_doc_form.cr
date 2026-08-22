class Docs::ReplyToDocForm < BaseComponent
  needs content : String = ""
  needs html_id : String = "tab"
  needs order_by : String? = nil
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
      order_by_input_id = "#{html_id}_order_by"
      after_submit = htmx_success <<-HEREDOC
set textarea to ##{html_id}_text_area
set input_tab to ##{html_id}1

if textarea
  clear textarea
end

if input_tab
  set input_tab's checked to true
end

close the closest <dialog/>
HEREDOC

      hx_include = if order_by
                     "[name='_csrf'],##{html_id}_text_area,##{order_by_input_id}"
                   else
                     "[name='_csrf'],##{html_id}_text_area,#replies-order-by"
                   end

      opts = {
        class:      "inline-flex items-center justify-center rounded-xl bg-sky-700 px-5 py-2 text-sm font-semibold text-white transition hover:bg-sky-800 disabled:cursor-not-allowed disabled:bg-gray-300 disabled:text-gray-500",
        hx_target:  "div#replies",
        hx_include: hx_include,
        hx_post:    Htmx::Docs::Reply::CreateOrUpdate.path_without_query_params,
        script:     after_submit,
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
            target_id = target_reply_id || reply_id
            opts = opts.merge(
              hx_vals: %({"user_id": #{me.id}, "id": #{reply_id}, "op": "new"}),
              hx_target: "#doc_reply-#{target_id}-replies",
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

      if !reply_id.nil? && !me.nil?
        button(
          "取消",
          script: "on click close the closest <dialog/>",
          class: "inline-flex items-center justify-center rounded-xl border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 transition hover:border-gray-400 hover:bg-gray-50"
        )
      end

      if (current_order_by = order_by)
        input type: "hidden", id: order_by_input_id, name: "order_by", value: current_order_by
      end

      button(text, opts)
    end
  end
end
