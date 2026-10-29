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
    section class: "#{page_container_classes} page-content" do
      div class: "flex flex-col items-start gap-8 lg:flex-row" do
        mount Admin::Sidebar

        # 右侧直接展示当前页面内容，与侧栏顶部对齐。
        div class: "w-full min-w-0 flex-1" do
          admin_content
        end
      end
    end
  end
end
