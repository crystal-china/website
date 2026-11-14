class Forum::NodeNavigation < BaseComponent
  needs nodes : Array(Node)
  needs node : Node? = nil
  needs followed_topics : Bool = false
  needs only_show_unread : Bool = false

  def render : Nil
    link_classes = "flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-medium whitespace-nowrap no-underline transition-colors"
    active_classes = "bg-gray-900 text-white"
    inactive_classes = "text-gray-700 hover:bg-gray-100 hover:text-gray-950"

    aside class: "w-full min-w-0 shrink-0 lg:w-56" do
      nav(
        class: "desktop-sidebar app-panel p-3 lg:w-56",
        "aria-label": r("forum_layout.nodes").t,
        "hx-target:inherited": "#forum-content",
        "hx-swap:inherited": "outerHTML show:top showTarget:body",
        "hx-sync:inherited": "#forum-content:replace"
      ) do
        ul class: "m-0 flex list-none gap-1 overflow-x-auto p-0 lg:flex-col lg:overflow-visible" do
          li class: "shrink-0" do
            link(
              r("forum_layout.all_topics").t,
              to: Forum::Index.with(
                following: followed_topics? ? true : nil,
                only_show_unread: only_show_unread? ? true : nil
              ),
              class: "#{link_classes} #{node.nil? ? active_classes : inactive_classes}"
            )
          end

          nodes.each do |listed_node|
            li class: "shrink-0" do
              link(
                to: Forum::Index.with(
                  node: listed_node.slug,
                  following: followed_topics? ? true : nil,
                  only_show_unread: only_show_unread? ? true : nil
                ),
                class: "#{link_classes} #{node.try(&.id) == listed_node.id ? active_classes : inactive_classes}"
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
end
