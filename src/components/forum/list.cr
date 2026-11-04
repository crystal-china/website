@[Rosetta::Translatable::Config(prefix: "forum.index_page")]
class Forum::List < BaseComponent
  needs topics : TopicQuery
  needs pages : Lucky::Paginator
  needs followed_topics : Bool = false
  needs only_show_unread : Bool = false
  needs unread_topic_ids : Set(Int64) = Set(Int64).new

  def render : Nil
    current_topics = topics.results

    section id: "forum-topics" do
      if current_topics.empty?
        para(
          empty_message,
          class: "app-panel m-0 px-6 py-10 text-center text-gray-500"
        )
      else
        div class: "app-panel divide-y divide-gray-200 overflow-hidden" do
          current_topics.each do |topic|
            render_topic_item(topic)
          end
        end
      end

      # 只让分页局部刷新；主题、作者和节点链接仍走整页导航。
      div(
        "hx-target:inherited": "#forum-topics",
        "hx-swap:inherited": "outerHTML show:top showTarget:body",
        "hx-sync:inherited": "#forum-topics:replace"
      ) do
        mount Shared::Pagination, pages: pages
      end
    end
  end

  private def render_topic_item(topic : Topic) : Nil
    article class: "flex flex-col gap-3 px-6 py-5 transition-colors hover:bg-gray-50 sm:flex-row sm:items-center" do
      div class: "min-w-0 flex-1" do
        h2 class: "relative m-0 text-lg font-semibold" do
          if unread_topic_ids.includes?(topic.id)
            span(
              title: r(".unread").t,
              class: "absolute -left-4 top-2 h-2 w-2 rounded-full bg-sky-500"
            )
          end

          link(
            topic.title,
            to: Forum::Show.with(
              id: topic.id,
              following: followed_topics? ? true : nil,
              only_show_unread: only_show_unread? ? true : nil
            ),
            class: "text-[#145591] no-underline hover:underline"
          )
        end

        para class: "mt-2 mb-0 flex flex-wrap items-center gap-x-1 text-xs text-gray-500" do
          link(
            to: Forum::Index.with(
              node: topic.node.slug,
              following: followed_topics? ? true : nil,
              only_show_unread: only_show_unread? ? true : nil
            ),
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

  private def empty_message : String
    if only_show_unread?
      r(".no_unread_topics").t
    elsif followed_topics?
      r(".no_followed_topics").t
    else
      r("common.no_topics").t
    end
  end
end
