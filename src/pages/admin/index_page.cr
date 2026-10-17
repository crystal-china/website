class Admin::IndexPage < AdminLayout
  needs users_count : Int64
  needs docs_count : Int64
  needs topics_count : Int64
  needs comments_count : Int64
  needs nodes_count : Int64
  needs recent_topics : Array(Topic)

  def page_title : String
    r(".page_title").t
  end

  def admin_content : Nil
    header class: "mb-6" do
      h2 r("common.dashboard").t, class: "m-0 text-2xl font-semibold tracking-tight text-gray-900"
      para r(".description").t, class: "mt-1.5 mb-0 text-sm text-gray-600"
    end

    section class: "grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5", "aria-label": r(".statistics").t do
      render_stat r("common.users").t, users_count
      render_stat r("common.docs").t, docs_count
      render_stat r("common.topic").t, topics_count
      render_stat r("common.comment").t, comments_count
      render_stat r("common.node").t, nodes_count
    end

    div class: "mt-8 grid gap-6 xl:grid-cols-[minmax(0,1fr)_18rem]" do
      section class: "app-panel overflow-hidden", "aria-labelledby": "recent-topics-title" do
        header class: "panel-header flex items-center justify-between gap-4" do
          h3 r(".recent_topics").t, id: "recent-topics-title", class: "m-0 text-lg font-semibold text-gray-900"
          link r(".view_all").t, to: Forum::Index, class: "text-sm font-medium text-[#145591] no-underline hover:underline"
        end

        if recent_topics.empty?
          para r("common.no_topics").t, class: "m-0 px-6 py-10 text-center text-sm text-gray-500"
        else
          ul class: "m-0 list-none divide-y divide-gray-200 p-0" do
            recent_topics.each do |topic|
              li class: "px-6 py-4 hover:bg-gray-50" do
                link topic.title, to: Forum::Show.with(id: topic.id), class: "font-semibold text-[#145591] no-underline hover:underline"

                para class: "mt-1.5 mb-0 flex flex-wrap items-center gap-x-1 text-xs text-gray-500" do
                  span class: "h-2.5 w-2.5 rounded-full", style: "background-color: #{topic.node.color}"
                  text "#{topic.node.name} · "
                  mount Shared::UserName, user: topic.user
                  text " · #{relative_time(topic.created_at)}"
                end
              end
            end
          end
        end
      end

      aside class: "app-panel p-6", "aria-labelledby": "quick-actions-title" do
        h3 r(".quick_actions").t, id: "quick-actions-title", class: "m-0 text-lg font-semibold text-gray-900"

        nav class: "mt-4", "aria-label": r(".quick_actions_navigation").t do
          ul class: "m-0 list-none space-y-3 p-0" do
            li { link r("common.new_node").t, to: Admin::Nodes::New, class: "form-secondary w-full" }
            li { link r(".manage_nodes").t, to: Admin::Nodes::Index, class: "form-secondary w-full" }
            li { link r("common.new_topic").t, to: Forum::New, class: "form-secondary w-full" }
          end
        end
      end
    end
  end

  private def render_stat(label : String, value : Int64) : Nil
    article class: "app-panel p-5" do
      para label, class: "m-0 text-sm font-medium text-gray-600"
      para value.to_s, class: "mt-2 mb-0 text-3xl font-semibold tracking-tight text-gray-950 tabular-nums"
    end
  end
end
