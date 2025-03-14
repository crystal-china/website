class Docs::ReplyForm < BaseComponent
  def render
    me = current_user

    textarea_opt = {
      id:   "text_area",
      rows: 8,
      cols: 70,
      name: "content",
    }

    if me.nil?
      legend_text = "登录后添加评论"
      # textarea_opt = textarea_opt.merge(disabled: "")
    else
      legend_text = "支持 markdown 格式"
    end

    # ---------------- page start ----------------

    div id: "tabs" do
      div role: "tablist", tableindex: "-1", aria_label: "" do
        button(
          "输入",
          role: "tab",
          id: "tab-1",
          aria_controls: "panel-1",
          tabindex: "0",
          aria_selected: "true"
        )

        button(
          role: "tab",
          id: "tab-2",
          aria_controls: "panel-2",
          tabindex: "-1",
          hx_put: "/docs/htmx/markdown_render",
          hx_target: "#markdown-preview",
          hx_include: "[name='_csrf'],#text_area",
          hx_indicator: "next img.htmx-indicator"
        ) do
          text "预览"
        end
      end

      div role: "tabpanel", id: "panel-1", aria_labelledby: "tab-1" do
        form do
          fieldset do
            # legend legend_text

            para do
              label legend_text, id: "text_area", style: "margin-bottom: 8px;"

              textarea textarea_opt
            end
          end
        end
      end
      div role: "tabpanel", id: "panel-2", aria_labelledby: "tab-2", hidden: "" do
        para id: "markdown-preview" do
        end
        mount Shared::Spinner, text: "正在预览..."
      end
    end
  end
end
