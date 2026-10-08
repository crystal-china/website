class Forum::IndexPage < ForumLayout
  needs topics : TopicQuery
  needs pages : Lucky::Paginator
  needs nodes : Array(Node)
  needs node : Node? = nil

  def page_title
    node.try { |current_node| "#{current_node.name} - 社区" } || "社区"
  end

  def content
    time_in_words = TimeInWords::Helpers(TimeInWords::I18n::ZH_CN)
    current_topics = topics.results
    current_node = node
    heading = current_node.try(&.name) || "社区"
    description = current_node.try(&.summary) || "讨论 Crystal 语言及其生态。"

    section class: "#{page_container_classes} py-10" do
      div class: "flex flex-col items-start gap-8 lg:flex-row" do
        render_node_navigation(current_node)

        main class: "min-w-0 flex-1" do
          header class: "mb-8 flex flex-wrap items-center justify-between gap-4" do
            div do
              h1 heading, class: "m-0 text-3xl font-semibold tracking-tight text-gray-900"
              para description, class: "mt-2 mb-0 text-sm text-gray-600"
            end

            link "发布主题", to: Forum::New, class: "form-submit" if current_user
          end

          render_topic_list(current_topics, time_in_words)
        end
      end
    end
  end

  private def render_node_navigation(current_node : Node?)
    link_classes = "flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-medium no-underline transition-colors"
    active_classes = "bg-gray-900 text-white"
    inactive_classes = "text-gray-700 hover:bg-gray-100 hover:text-gray-950"

    aside class: "app-panel w-full shrink-0 p-3 lg:sticky lg:top-24 lg:w-56" do
      nav "aria-label": "社区节点" do
        ul class: "m-0 flex list-none flex-wrap gap-1 p-0 lg:flex-col" do
          li do
            link(
              "全部主题",
              to: Forum::Index,
              class: "#{link_classes} #{current_node.nil? ? active_classes : inactive_classes}"
            )
          end

          nodes.each do |listed_node|
            li do
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

  private def render_topic_list(current_topics : Array(Topic), time_in_words)
    if current_topics.empty?
      para "还没有主题。", class: "app-panel m-0 px-6 py-10 text-center text-gray-500"
    else
      div class: "app-panel divide-y divide-gray-200 overflow-hidden" do
        current_topics.each do |topic|
          render_topic(topic, time_in_words)
        end
      end

      render_pagination unless pages.one_page?
    end
  end

  private def render_topic(topic : Topic, time_in_words)
    article class: "flex flex-col gap-3 px-6 py-5 transition-colors hover:bg-gray-50 sm:flex-row sm:items-center" do
      div class: "min-w-0 flex-1" do
        h2 class: "m-0 text-lg font-semibold" do
          link topic.title, to: Forum::Show.with(id: topic.id), class: "text-[#145591] no-underline hover:underline"
        end

        para class: "mt-2 mb-0 flex flex-wrap items-center gap-x-1 text-xs text-gray-500" do
          link(
            to: Forum::Index.with(node: topic.node.slug),
            title: topic.node.name,
            "aria-label": "节点：#{topic.node.name}",
            class: "inline-flex h-5 w-5 items-center justify-center rounded-full no-underline hover:bg-gray-200"
          ) do
            span class: "h-2.5 w-2.5 rounded-full", style: "background-color: #{topic.node.color}"
          end
          text "#{topic.user.name} 发布于 #{time_in_words.from(past_time: topic.created_at)}"

          if (edited_at = topic.edited_at)
            text " · 编辑于 #{time_in_words.from(past_time: edited_at)}"
          end
        end
      end

      div class: "flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-gray-500 sm:shrink-0 sm:flex-col sm:items-end" do
        span "#{topic.replies_count} 条回复", class: "font-medium text-gray-700"
        if (last_reply_user = topic.last_reply_user)
          span "最后回复：#{last_reply_user.name}"
        end
        span(
          "最后活跃于 #{time_in_words.from(past_time: topic.last_active_at)}",
          title: topic.last_active_at.to_local.to_s("%Y-%m-%d %H:%M:%S")
        )
      end
    end
  end

  private def render_pagination
    nav class: "mt-6 flex items-center justify-center gap-4 text-sm", "aria-label": "社区分页" do
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
