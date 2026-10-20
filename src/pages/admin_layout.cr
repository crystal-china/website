require "./main_layout"

abstract class AdminLayout < MainLayout
  abstract def admin_content : Nil

  def page_title : String
    r("admin_layout.page_title").t
  end

  def page_description : String
    r("admin_layout.description").t
  end

  def content : Nil
    section class: "#{page_container_classes} py-10" do
      div class: "flex flex-col items-start gap-8 lg:flex-row" do
        mount Admin::Sidebar, current_user: current_user

        # 标题挪到右侧内容列，让它和侧栏顶部对齐。
        div class: "w-full min-w-0 flex-1" do
          header class: "mb-8" do
            h1 r("admin_layout.page_title").t, class: "m-0 text-3xl font-semibold tracking-tight text-gray-900"
            para r("admin_layout.introduction").t, class: "mt-2 mb-0 text-sm text-gray-600"
          end

          admin_content
        end
      end
    end
  end
end
