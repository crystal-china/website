class Comments::Form < BaseComponent
  needs content : String = ""
  needs html_id : String = "tab"
  needs order_by : String? = nil
  needs comment_thread_id : Int64? = nil
  needs comment_id : Int64?
  needs target_comment_id : Int64? = nil

  def render : Nil
    me = current_user
    text = r("common.reply").t
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

    opts = {
      hx_target:   "#comments",
      hx_post:     Htmx::Comments::CreateOrUpdate.path_without_query_params,
      hx_swap:     "outerHTML",
      hx_push_url: "false",
      hx_disable:  "find button[type=submit]",
      script:      after_submit,
    }

    opts = opts.merge(hx_include: "#comments-order-by") unless order_by

    if (key = draft_key)
      opts = opts.merge(data_draft_key: key)
    end

    unless me.nil?
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
            hx_target: "#comment-#{target_id}-comments"
          )
        else
          opts = opts.merge(
            hx_vals: %({"id": #{comment_id}, "op": "edit"}),
            hx_target: "#comment-#{comment_id}-content",
          )
          text = r("common.update").t
        end
      else
        # 为 CommentThread 新建顶级评论
        thread_id = comment_thread_id.not_nil!
        opts = opts.merge(
          hx_vals: %({"comment_thread_id": #{thread_id}}),
        )
      end
    end

    submit_opts = {
      type:    "submit",
      class:   "form-submit py-2 disabled:cursor-not-allowed disabled:bg-gray-300 disabled:text-gray-500",
      flow_id: "#{html_id}-do_comment",
    }
    submit_opts = submit_opts.merge(disabled: "") if me.nil?

    form(
      opts,
      id: "#{html_id}-form",
      action: Htmx::Comments::CreateOrUpdate.path_without_query_params,
      method: "post"
    ) do
      csrf_hidden_input

      if (current_order_by = order_by)
        input(
          type: "hidden",
          id: order_by_input_id,
          name: "order_by",
          value: current_order_by
        )
      end

      mount(
        Shared::MarkdownEditor,
        content: content,
        current_user: me,
        html_id: html_id
      ) do
        if !comment_id.nil? && !me.nil?
          button(
            r("common.cancel").t,
            type: "button",
            script: "on click send closeRequested to the closest <dialog/>",
            class: "form-secondary px-4 py-2"
          )
        end

        button(text, submit_opts)
      end
    end
  end

  private def draft_key : String?
    me = current_user

    # 未登录，不启用草稿。
    return if me.nil?

    target = if comment_id
               # 回复评论 20：         7:reply:20
               # 编辑评论 20：         7:comment:20:edit
               content.blank? ? "reply:#{comment_id}" : "comment:#{comment_id}:edit"
             else
               # 给评论区 10 发顶级评论：7:thread:10
               "thread:#{comment_thread_id}"
             end

    "#{me.id}:#{target}"
  end
end
