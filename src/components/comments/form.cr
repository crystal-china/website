class Comments::Form < BaseComponent
  needs content : String = ""
  needs html_id : String = "tab"
  needs order_by : String? = nil
  needs comment_thread_id : Int64? = nil
  needs comment_id : Int64?
  needs target_comment_id : Int64? = nil

  def render
    mount(
      Comments::Editor,
      content: content,
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
                     "##{html_id}_text_area,##{order_by_input_id}"
                   else
                     "##{html_id}_text_area,#comments-order-by"
                   end

      opts = {
        class:      "inline-flex items-center justify-center rounded-xl bg-sky-700 px-5 py-2 text-sm font-semibold text-white transition hover:bg-sky-800 disabled:cursor-not-allowed disabled:bg-gray-300 disabled:text-gray-500",
        hx_target:  "#comments",
        hx_include: hx_include,
        hx_post:    Htmx::Comments::CreateOrUpdate.path_without_query_params,
        hx_disable: "this",
        script:     after_submit,
        flow_id:    "#{html_id}-do_comment",
      }

      if me.nil?
        opts = opts.merge(disabled: "")
      else
        if !comment_id.nil?
          # comment_id 不为空，说明当前表单针对的是一条已有评论。
          # 然后再用 content 是否为空区分表单模式：
          # - 空：这是“回复这条评论”，即新建子评论
          # - 非空：这是“编辑这条已有评论”
          if content.blank?
            # 为评论新增评论
            target_id = target_comment_id || comment_id
            opts = opts.merge(
              hx_vals: %({"id": #{comment_id}, "op": "new"}),
              hx_target: "#comment-#{target_id}-comments",
              hx_swap: "outerHTML"
            )
          else
            # 编辑子评论时，Action 会传入所属根评论 ID，用于替换整个子评论列表。
            # 编辑顶级评论时该值为 nil，沿用默认的 #comments 目标。
            if target_comment_id
              opts = opts.merge(
                hx_target: "#comment-#{target_comment_id}-comments"
              )
            end

            opts = opts.merge(
              hx_vals: %({"id": #{comment_id}, "op": "edit"}),
              hx_swap: "outerHTML",
            )
            text = "修改"
          end
        else
          # 为 CommentThread 新建顶级评论
          thread_id = comment_thread_id.not_nil!
          opts = opts.merge(
            hx_vals: %({"comment_thread_id": #{thread_id}}),
          )
        end
      end

      if !comment_id.nil? && !me.nil?
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
