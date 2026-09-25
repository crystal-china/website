class Forum::NewPage < MainLayout
  needs operation : SaveTopic

  def page_title
    "发布主题"
  end

  def content
    section class: "#{page_container_classes} py-10" do
      article class: "app-panel mx-auto w-full max-w-3xl overflow-hidden" do
        header class: "panel-header" do
          h1 "发布主题", class: "panel-title"
        end

        form_for Forum::Create, class: "panel-body space-y-6" do
          mount Shared::Field, attribute: operation.title, label_text: "标题", &.text_input(autofocus: "true", required: "")

          div class: "form-field" do
            label "正文", for: "topic_text_area", class: "form-label"

            mount(
              Comments::Editor,
              content: operation.content.value || "",
              current_user: current_user,
              html_id: "topic"
            ) do
              link "取消", to: Forum::Index, class: "form-secondary"
              submit "发布", class: "form-submit"
            end

            mount Shared::FieldErrors, operation.content
          end
        end
      end
    end
  end
end
