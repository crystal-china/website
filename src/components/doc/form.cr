class Docs::Form < BaseComponent
  needs content : String = ""
  needs doc_path : String?
  needs reply_id : Int64?
  needs html_id : String = "tab"

  def render(&)
    me = current_user
    div style: "border:0.5px solid gray; padding: 5px;", id: "#{html_id}-form" do
      div class: "tab-frame", style: "margin-top: 5px;text-align: center; min-height: 350px;" do
        input type: "radio", checked: "", name: "#{html_id}", id: "#{html_id}1"
        label "输入", for: "#{html_id}1", style: "margin-right: 5px;", flow_id: "#{html_id}-input_reply"

        input(
          type: "radio",
          name: "#{html_id}",
          id: "#{html_id}2",
          hx_put: Htmx::Docs::MarkdownRender.path_without_query_params,
          hx_target: "next p.markdown-preview",
          hx_include: "[name='_csrf'],next textarea",
          hx_indicator: "next img.htmx-indicator",
        )
        label(
          "预览",
          for: "#{html_id}2",
          flow_id: "#{html_id}-preview_reply",
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

        output style: "display: inline-block;" do
          text me.nil? ? "登录后添加评论" : "支持 markdown 格式"
        end

        yield

        div class: "tab" do
          render_form
        end
        div class: "tab", style: "text-align: initial;" do
          render_preview
        end
      end
    end
  end

  private def render_form
    me = current_user

    textarea_opt = {
      id:   "#{html_id}_text_area",
      rows: 16,
      cols: 70,
      name: "content",
    }

    textarea_opt = textarea_opt.merge(disabled: "") if me.nil?

    form do
      para do
        textarea textarea_opt do
          text content
        end
      end
    end
  end

  private def render_preview
    para class: "markdown-preview"
    mount Shared::Spinner, text: "正在预览..."
  end
end
