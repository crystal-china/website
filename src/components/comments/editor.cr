class Comments::Editor < BaseComponent
  needs content : String = ""
  needs html_id : String = "tab"

  def render(&)
    me = current_user
    id_input = "#{html_id}1"
    id_preview = "#{html_id}2"
    editor_height = "h-[11rem] min-h-[11rem] max-h-[40rem]"

    div class: "app-panel", id: "#{html_id}-form" do
      input(
        type: "radio",
        checked: "",
        name: html_id,
        id: id_input,
        class: "input1 sr-only"
      )

      input(
        type: "radio",
        name: html_id,
        id: id_preview,
        class: "input2 sr-only",
        hx_put: Htmx::Docs::MarkdownRender.path_without_query_params,
        hx_target: "next div.markdown-preview",
        hx_include: "##{html_id}_text_area",
        hx_indicator: "next img.htmx-indicator",
        script: "bind @disabled to (the value of ##{html_id}_text_area is empty)",
      )

      div class: "panel-toolbar doc-form-toolbar grid gap-4 p-4 md:grid-cols-[auto_1fr_auto] md:items-center" do
        div class: "segmented-control" do
          label(
            "输入",
            for: id_input,
            flow_id: "#{html_id}-input_comment",
            class: "segmented-option label1 cursor-pointer"
          )

          label(
            "预览",
            for: id_preview,
            flow_id: "#{html_id}-preview_comment",
            class: "segmented-option label2 cursor-pointer",
            script: <<-HEREDOC
  on click
    set textarea to ##{html_id}_text_area
    set preview to ##{html_id}_preview
    set preview.style.height to `${textarea.offsetHeight}px`
  end

  on mouseenter
    if the value of ##{html_id}_text_area is empty
      set my *cursor to "not-allowed"
    else
      set my *cursor to "pointer"
    end
  end
HEREDOC
          )
        end

        output class: "text-center text-base font-semibold text-gray-900 md:px-4" do
          text me.nil? ? "登录后添加评论" : "支持 markdown 格式"
        end

        div class: "flex items-center justify-end gap-2" do
          yield
        end
      end

      div class: "panel1 hidden p-4" do
        render_form(editor_height)
      end

      div class: "panel2 hidden p-4" do
        render_preview(editor_height)
      end
    end
  end

  private def render_form(editor_height : String)
    me = current_user

    textarea_opt = {
      id:       "#{html_id}_text_area",
      rows:     5,
      name:     "content",
      required: "",
      class:    "#{editor_height} block w-full resize-y overflow-y-auto rounded-xl border border-gray-300 bg-white px-4 py-3 text-sm leading-7 text-gray-900 shadow-inner transition outline-none placeholder:text-gray-400 focus:border-sky-400 focus:ring-2 focus:ring-sky-100 disabled:cursor-not-allowed disabled:bg-gray-50 disabled:text-gray-400",
    }

    textarea_opt = textarea_opt.merge(disabled: "") if me.nil?

    textarea textarea_opt do
      text content
    end
  end

  private def render_preview(editor_height : String)
    div id: "#{html_id}_preview", class: "#{editor_height} overflow-y-auto rounded-xl border border-gray-200 bg-gray-50/60 px-4 py-3" do
      div class: "markdown-preview"
      mount Shared::Spinner, text: "正在预览..."
    end
  end
end
