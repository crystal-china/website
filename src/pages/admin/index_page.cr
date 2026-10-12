class Admin::IndexPage < AdminLayout
  needs users_count : Int64
  needs docs_count : Int64
  needs topics_count : Int64
  needs comments_count : Int64
  needs nodes_count : Int64
  needs recent_topics : Array(Topic)

  def page_title
    "后台概览"
  end

  def admin_content
    time_in_words = TimeInWords::Helpers(TimeInWords::I18n::ZH_CN)

    header class: "mb-6" do
      h2 "概览", class: "m-0 text-2xl font-semibold tracking-tight text-gray-900"
      para "查看站点当前的数据规模和最近内容。", class: "mt-1.5 mb-0 text-sm text-gray-600"
    end

    section class: "grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5", "aria-label": "站点统计" do
      render_stat "用户", users_count
      render_stat "文档", docs_count
      render_stat "主题", topics_count
      render_stat "评论", comments_count
      render_stat "节点", nodes_count
    end

    div class: "mt-8 grid gap-6 xl:grid-cols-[minmax(0,1fr)_18rem]" do
      section class: "app-panel overflow-hidden", "aria-labelledby": "recent-topics-title" do
        header class: "panel-header flex items-center justify-between gap-4" do
          h3 "最近主题", id: "recent-topics-title", class: "m-0 text-lg font-semibold text-gray-900"
          link "查看全部", to: Forum::Index, class: "text-sm font-medium text-[#145591] no-underline hover:underline"
        end

        if recent_topics.empty?
          para "还没有主题。", class: "m-0 px-6 py-10 text-center text-sm text-gray-500"
        else
          ul class: "m-0 list-none divide-y divide-gray-200 p-0" do
            recent_topics.each do |topic|
              li class: "px-6 py-4 hover:bg-gray-50" do
                link topic.title, to: Forum::Show.with(id: topic.id), class: "font-semibold text-[#145591] no-underline hover:underline"

                para class: "mt-1.5 mb-0 flex flex-wrap items-center gap-x-1 text-xs text-gray-500" do
                  span class: "h-2.5 w-2.5 rounded-full", style: "background-color: #{topic.node.color}"
                  text "#{topic.node.name} · #{topic.user.nickname} (@#{topic.user.login_name}) · #{time_in_words.from(past_time: topic.created_at)}"
                end
              end
            end
          end
        end
      end

      aside class: "app-panel p-6", "aria-labelledby": "quick-actions-title" do
        h3 "快捷操作", id: "quick-actions-title", class: "m-0 text-lg font-semibold text-gray-900"

        nav class: "mt-4", "aria-label": "后台快捷操作" do
          ul class: "m-0 list-none space-y-3 p-0" do
            li { link "新增节点", to: Admin::Nodes::New, class: "form-secondary w-full" }
            li { link "管理节点", to: Admin::Nodes::Index, class: "form-secondary w-full" }
            li { link "发布主题", to: Forum::New, class: "form-secondary w-full" }
          end
        end
      end
    end
  end

  private def render_stat(label : String, value : Int64)
    article class: "app-panel p-5" do
      para label, class: "m-0 text-sm font-medium text-gray-600"
      para value.to_s, class: "mt-2 mb-0 text-3xl font-semibold tracking-tight text-gray-950 tabular-nums"
    end
  end
end
