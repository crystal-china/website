require "./main_layout"

abstract class AdminLayout < MainLayout
  abstract def admin_content : Nil

  def page_title : String
    "后台管理"
  end

  def page_description : String
    "管理 Crystal 中文社区。"
  end

  def content : Nil
    section class: "#{page_container_classes} py-10" do
      header class: "mb-8" do
        h1 "后台管理", class: "m-0 text-3xl font-semibold tracking-tight text-gray-900"
        para "管理社区内容和配置。", class: "mt-2 mb-0 text-sm text-gray-600"
      end

      div class: "flex flex-col items-start gap-8 lg:flex-row" do
        aside class: "app-panel w-full shrink-0 p-3 lg:sticky lg:top-24 lg:w-56" do
          nav "aria-label": "后台管理" do
            ul class: "m-0 flex list-none flex-wrap gap-1 p-0 lg:flex-col" do
              li do
                link(
                  "概览",
                  to: Admin::Index,
                  class: admin_nav_link_classes(active: current_path == Admin::Index.path)
                )
              end

              li do
                link(
                  "节点管理",
                  to: Admin::Nodes::Index,
                  class: admin_nav_link_classes(active: current_path.starts_with?("/admin/nodes"))
                )
              end

              li do
                link(
                  "回收站",
                  to: Admin::Trash::Index,
                  class: admin_nav_link_classes(active: current_path.starts_with?("/admin/trash"))
                )
              end
            end
          end
        end

        div class: "min-w-0 flex-1" do
          admin_content
        end
      end
    end
  end

  private def admin_nav_link_classes(*, active : Bool) : String
    base = "flex items-center rounded-lg px-3 py-2 text-sm font-medium no-underline transition-colors"
    state = active ? "bg-gray-900 text-white" : "text-gray-700 hover:bg-gray-100 hover:text-gray-950"

    "#{base} #{state}"
  end
end
