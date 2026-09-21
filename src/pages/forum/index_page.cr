class Forum::IndexPage < MainLayout
  needs topics : TopicQuery
  needs pages : Lucky::Paginator

  def page_title
    "论坛"
  end

  def content
    current_topics = topics.results

    section class: "#{page_container_classes} py-10" do
      header class: "mb-8 flex flex-wrap items-center justify-between gap-4" do
        div do
          h1 "论坛", class: "m-0 text-3xl font-semibold tracking-tight text-gray-900"
          para "讨论 Crystal 语言及其生态。", class: "mt-2 mb-0 text-sm text-gray-600"
        end

        link "发布主题", to: Forum::New, class: "form-submit" if current_user
      end

      if current_topics.empty?
        para "还没有主题。", class: "m-0 rounded-2xl border border-gray-200 bg-white px-6 py-10 text-center text-gray-500"
      else
        div class: "divide-y divide-gray-200 overflow-hidden rounded-2xl border border-gray-200 bg-white" do
          current_topics.each do |topic|
            article class: "px-6 py-5 hover:bg-gray-50" do
              h2 class: "m-0 text-lg font-semibold" do
                link topic.title, to: Forum::Show.with(id: topic.id), class: "text-[#145591] no-underline hover:underline"
              end

              para class: "mt-2 mb-0 text-xs text-gray-500" do
                text "#{topic.user.name} 发布于 #{topic.created_at.to_s("%Y-%m-%d %H:%M")}"
              end
            end
          end
        end

        render_pagination unless pages.one_page?
      end
    end
  end

  private def render_pagination
    nav class: "mt-6 flex items-center justify-center gap-4 text-sm", "aria-label": "论坛分页" do
      if (previous_path = pages.path_to_previous)
        a "上一页", href: previous_path, class: "form-secondary"
      else
        span "上一页", class: "form-secondary cursor-not-allowed opacity-50"
      end

      span "第 #{pages.page} / #{pages.total} 页", class: "text-gray-600"

      if (next_path = pages.path_to_next)
        a "下一页", href: next_path, class: "form-secondary"
      else
        span "下一页", class: "form-secondary cursor-not-allowed opacity-50"
      end
    end
  end
end
