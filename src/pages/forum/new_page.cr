class Forum::NewPage < MainLayout
  needs operation : SaveTopic

  def page_title
    "发布主题"
  end

  def content
    section class: "#{page_container_classes} py-10" do
      article class: "mx-auto w-full max-w-3xl overflow-hidden rounded-2xl border border-gray-200 bg-white shadow-sm" do
        header class: "border-b border-gray-200 px-8 py-6" do
          h1 "发布主题", class: "m-0 text-2xl font-semibold text-gray-900"
        end

        form_for Forum::Create, class: "space-y-6 px-8 py-8" do
          mount Shared::Field, attribute: operation.title, label_text: "标题", &.text_input(autofocus: "true", required: "")
          mount Shared::Field, attribute: operation.content, label_text: "正文", &.textarea(rows: 14, required: "")

          div class: "flex items-center justify-end gap-3 border-t border-gray-200 pt-6" do
            link "取消", to: Forum::Index, class: "form-secondary"
            submit "发布", class: "form-submit"
          end
        end
      end
    end
  end
end
