class Admin::Sidebar < BaseComponent
  def render : Nil
    aside class: "w-full shrink-0 lg:w-56" do
      nav(
        class: "desktop-sidebar app-panel p-3 lg:w-56",
        "aria-label": r("admin_layout.page_title").t
      ) do
        ul class: "m-0 flex list-none flex-wrap gap-1 p-0 lg:flex-col" do
          li do
            link(
              r("common.dashboard").t,
              to: Admin::Index,
              class: admin_nav_link_classes(active: current_path == Admin::Index.path)
            )
          end

          li do
            link(
              r("common.nodes").t,
              to: Admin::Nodes::Index,
              class: admin_nav_link_classes(active: current_path.starts_with?("/admin/nodes"))
            )
          end

          li do
            link(
              r("common.events").t,
              to: UserAudits::Index,
              class: admin_nav_link_classes(active: current_path == UserAudits::Index.path)
            )
          end

          li do
            link(
              r("common.trash").t,
              to: Admin::Trash::Index,
              class: admin_nav_link_classes(active: current_path.starts_with?("/admin/trash"))
            )
          end
        end
      end
    end
  end

  private def admin_nav_link_classes(*, active : Bool = false) : String
    base = "flex items-center rounded-lg px-3 py-2 text-sm font-medium no-underline transition-colors"
    state = active ? "bg-gray-900 text-white" : "text-gray-700 hover:bg-gray-100 hover:text-gray-950"

    "#{base} #{state}"
  end
end
