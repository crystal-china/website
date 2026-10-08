require "./main_layout"

abstract class ForumLayout < MainLayout
  needs nodes : Array(Node)

  abstract def forum_content

  def content
    section class: "#{page_container_classes} py-10" do
      if show_sidebars?
        div class: "flex flex-col items-start gap-8 lg:flex-row" do
          render_node_navigation(current_node)

          div class: "min-w-0 w-full flex-1" do
            forum_content
          end

          if show_right_sidebar?
            aside class: "hidden w-56 shrink-0 space-y-4 xl:block", "aria-label": "社区辅助信息" do
              render_right_sidebar
            end
          end
        end
      else
        forum_content
      end
    end
  end

  private def render_node_navigation(current_node : Node?)
    link_classes = "flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-medium whitespace-nowrap no-underline transition-colors"
    active_classes = "bg-gray-900 text-white"
    inactive_classes = "text-gray-700 hover:bg-gray-100 hover:text-gray-950"

    aside class: "app-panel min-w-0 w-full shrink-0 p-3 lg:sticky lg:top-24 lg:w-56" do
      nav "aria-label": "社区节点" do
        ul class: "m-0 flex list-none gap-1 overflow-x-auto p-0 lg:flex-col lg:overflow-visible" do
          li class: "shrink-0" do
            link(
              "全部主题",
              to: Forum::Index,
              class: "#{link_classes} #{current_node.nil? ? active_classes : inactive_classes}"
            )
          end

          nodes.each do |listed_node|
            li class: "shrink-0" do
              link(
                to: Forum::Index.with(node: listed_node.slug),
                class: "#{link_classes} #{current_node.try(&.id) == listed_node.id ? active_classes : inactive_classes}"
              ) do
                span class: "h-2.5 w-2.5 shrink-0 rounded-sm", style: "background-color: #{listed_node.color}"
                text listed_node.name
              end
            end
          end
        end
      end
    end
  end

  private def current_node : Node?
    nil
  end

  private def show_sidebars? : Bool
    true
  end

  private def show_right_sidebar? : Bool
    false
  end

  private def render_right_sidebar
  end

  private def search_scope : String?
    "topics"
  end
end
