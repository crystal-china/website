class Forum::IndexPage < ForumLayout
  needs topics : TopicQuery
  needs pages : Lucky::Paginator
  needs node : Node? = nil

  def page_title : String
    node.try { |current_node| r(".node_title").t(name: current_node.name) } || r("common.community").t
  end

  def forum_content : Nil
    current_topics = topics.results
    current_node = node
    heading = current_node.try(&.name) || r("common.community").t
    description = current_node.try(&.summary) || r(".description").t

    header class: "mb-8 flex flex-wrap items-center justify-between gap-4" do
      div do
        h1 heading, class: "m-0 text-3xl font-semibold tracking-tight text-gray-900"
        para description, class: "mt-2 mb-0 text-sm text-gray-600"
      end

      link r("common.new_topic").t, to: Forum::New, class: "form-submit" if current_user
    end

    render_topic_list(current_topics)
  end

  private def current_node : Node?
    node
  end

  private def render_topic_list(current_topics : Array(Topic)) : Nil
    if current_topics.empty?
      para r("common.no_topics").t, class: "app-panel m-0 px-6 py-10 text-center text-gray-500"
    else
      div class: "app-panel divide-y divide-gray-200 overflow-hidden" do
        current_topics.each do |topic|
          render_topic(topic)
        end
      end

      render_pagination unless pages.one_page?
    end
  end

  private def render_topic(topic : Topic) : Nil
    article class: "flex flex-col gap-3 px-6 py-5 transition-colors hover:bg-gray-50 sm:flex-row sm:items-center" do
      div class: "min-w-0 flex-1" do
        h2 class: "m-0 text-lg font-semibold" do
          link topic.title, to: Forum::Show.with(id: topic.id), class: "text-[#145591] no-underline hover:underline"
        end

        para class: "mt-2 mb-0 flex flex-wrap items-center gap-x-1 text-xs text-gray-500" do
          link(
            to: Forum::Index.with(node: topic.node.slug),
            title: topic.node.name,
            "aria-label": r(".node_label").t(name: topic.node.name),
            class: "inline-flex h-5 w-5 items-center justify-center rounded-full no-underline hover:bg-gray-200"
          ) do
            span class: "h-2.5 w-2.5 rounded-full", style: "background-color: #{topic.node.color}"
          end
          mount Shared::UserName, user: topic.user
          local_time(
            topic.created_at,
            r(".posted_at").t(time: relative_time(topic.created_at))
          )

          if (edited_at = topic.edited_at)
            local_time(
              edited_at,
              r(".edited_at").t(time: relative_time(edited_at))
            )
          end
        end
      end

      div class: "flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-gray-500 sm:shrink-0 sm:flex-col sm:items-end" do
        span r(".reply_count").t(count: topic.replies_count), class: "font-medium text-gray-700"
        if (last_reply_user = topic.last_reply_user)
          span do
            text r(".last_reply").t
            mount Shared::UserName, user: last_reply_user
          end
        end
        local_time(
          topic.last_active_at,
          r(".last_active_at").t(
            time: relative_time(topic.last_active_at)
          )
        )
      end
    end
  end

  private def render_pagination : Nil
    nav class: "mt-6 flex items-center justify-center gap-4 text-sm", "aria-label": r(".pagination").t do
      if (previous_path = pages.path_to_previous)
        a r("common.previous_page").t, href: previous_path, class: "form-secondary"
      else
        span r("common.previous_page").t, class: "form-secondary cursor-not-allowed opacity-50"
      end

      span r("common.page_number").t(page: pages.page.to_s, total: pages.total.to_s), class: "text-gray-600"

      if (next_path = pages.path_to_next)
        a r("common.next_page").t, href: next_path, class: "form-secondary"
      else
        span r("common.next_page").t, class: "form-secondary cursor-not-allowed opacity-50"
      end
    end
  end
end
