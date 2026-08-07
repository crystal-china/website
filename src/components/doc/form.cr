class Docs::Form < BaseComponent
  needs content : String = ""
  needs doc_path : String?
  needs reply_id : Int64?
  needs html_id : String = "tab"

  def render(&)
    me = current_user
    id_input = "#{html_id}1"
    id_preview = "#{html_id}2"

    div class: "rounded-2xl border border-gray-300 bg-white shadow-sm", id: "#{html_id}-form" do
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
        hx_target: "next p.markdown-preview",
        hx_include: "[name='_csrf'],next textarea",
        hx_indicator: "next img.htmx-indicator",
      )

      div class: "grid gap-4 border-b border-gray-200 p-4 md:grid-cols-[auto_1fr_auto] md:items-center" do
        div class: "flex items-center gap-2" do
          label(
            "输入",
            for: id_input,
            flow_id: "#{html_id}-input_reply",
            class: "label1 cursor-pointer rounded-full border border-gray-300 bg-gray-100 px-5 py-2 text-lg font-medium text-gray-600 transition"
          )

          label(
            "预览",
            for: id_preview,
            flow_id: "#{html_id}-preview_reply",
            class: "label2 cursor-pointer rounded-full border border-transparent bg-gray-200 px-5 py-2 text-lg font-medium text-gray-500 transition",
            script: "on mouseover set x to the value of the next <textarea/>
        then if x == ''
           add @disabled to the previous <input/>
           then set the style of me to 'cursor: not-allowed;'
        else
          remove @disabled from the previous <input/>
          then remove @style from me
        end
        "
          )
        end

        output class: "text-center text-lg font-semibold text-gray-900 md:px-4" do
          text me.nil? ? "登录后添加评论" : "支持 markdown 格式"
        end

        div class: "flex items-center justify-end gap-2" do
          yield
        end
      end

      div class: "panel1 hidden p-4" do
        render_form
      end

      div class: "panel2 hidden p-4" do
        render_preview
      end
    end
  end

  private def render_form
    me = current_user

    textarea_opt = {
      id:    "#{html_id}_text_area",
      rows:  16,
      cols:  70,
      name:  "content",
      class: "min-h-[22rem] w-full rounded-xl border border-gray-300 bg-white px-4 py-3 text-base leading-7 text-gray-900 shadow-inner transition outline-none placeholder:text-gray-400 focus:border-sky-400 focus:ring-2 focus:ring-sky-100 disabled:cursor-not-allowed disabled:bg-gray-50 disabled:text-gray-400",
    }

    textarea_opt = textarea_opt.merge(disabled: "") if me.nil?

    form class: "w-full" do
      textarea textarea_opt do
        text content
      end
    end
  end

  private def render_preview
    div class: "min-h-[22rem] rounded-xl border border-gray-200 bg-gray-50/60 px-4 py-3" do
      para class: "markdown-preview min-h-[18rem]"
      mount Shared::Spinner, text: "正在预览..."
    end
  end
end
