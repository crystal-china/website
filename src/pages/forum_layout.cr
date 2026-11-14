require "./main_layout"

abstract class ForumLayout < MainLayout
  needs nodes : Array(Node)

  # 左侧节点导航，需要知道当前筛选状态
  needs followed_topics : Bool = false
  needs only_show_unread : Bool = false

  abstract def forum_content : Nil

  # 列表和详情共用社区区域；普通访问仍由 MainLayout 输出完整页面。
  def render : Nil
    if context.request.headers["HX-Request-Type"]? == "partial"
      mount(
        Shared::PagePartials,
        seo: SEO.new(
          page_title: page_title,
          page_description: page_description,
          canonical_url: canonical_url
        )
      )

      content
    else
      super
    end
  end

  def content : Nil
    section id: "forum-content", class: "#{page_container_classes} page-content" do
      if show_sidebars?
        div class: "flex flex-col items-start gap-8 lg:flex-row" do
          mount(
            Forum::NodeNavigation,
            nodes: nodes,
            node: current_node,
            followed_topics: followed_topics?,
            only_show_unread: only_show_unread?
          )

          div class: "w-full min-w-0 flex-1" do
            forum_content
          end

          if show_right_sidebar?
            aside class: "hidden w-56 shrink-0 space-y-4 xl:block", "aria-label": r("forum_layout.sidebar").t do
              render_right_sidebar
            end
          end
        end
      else
        forum_content
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

  private def render_right_sidebar : Nil
  end

  private def search_scope : String?
    "topics"
  end
end
