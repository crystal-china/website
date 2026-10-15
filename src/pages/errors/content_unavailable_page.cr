class Errors::ContentUnavailablePage < MainLayout
  needs content_name : String

  def page_title : String
    "#{content_name}已删除或暂不可见"
  end

  def content : Nil
    section class: "#{page_container_classes} py-10" do
      div class: "app-panel mx-auto max-w-2xl px-6 py-10 sm:px-8" do
        para "404", class: "m-0 text-sm font-semibold text-gray-400"
        h1 page_title, class: "mt-3 text-2xl font-semibold text-gray-900"
        para "这条#{content_name}可能已被删除，或所属主题、评论已被隐藏。", class: "mt-4 text-gray-600"

        nav class: "mt-6 flex flex-wrap gap-3", "aria-label": "其他页面" do
          link "查看社区", to: Forum::Index, class: "form-secondary"
          link "查看文档", to: Docs::Markdowns.with(requested_path: "index"), class: "form-secondary"
        end
      end
    end
  end
end
