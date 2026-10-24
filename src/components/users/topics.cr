class Users::Topics < BaseComponent
  needs user : User
  needs entries : Array(Topic) | Array(Comment)
  needs pages : Lucky::Paginator
  needs show_replies : Bool

  def render : Nil
    created_path = Users::Show.with(login_name: user.login_name).path
    replied_path = Users::Show.with(login_name: user.login_name, show_replies: true).path

    section id: "user-topics" do
      div class: "app-panel overflow-hidden" do
        div(
          class: "border-b border-gray-200 px-6 py-4",
          "hx-target:inherited": "#user-topics",
          "hx-swap:inherited": "outerHTML show:none",
          "hx-sync:inherited": "#user-topics:replace"
        ) do
          mount(
            Shared::Toggle,
            options: [{r(".created").t, created_path}, {r(".replied").t, replied_path}],
            selected: show_replies? ? replied_path : created_path
          )
        end

        if entries.empty?
          para show_replies? ? r(".no_replies").t : r(".no_topics").t, class: "m-0 px-6 py-10 text-center text-sm text-gray-500"
        else
          div class: "divide-y divide-gray-100" do
            entries.each do |entry|
              case entry
              when Comment
                render_entry(
                  entry.comment_thread.topic.not_nil!,
                  entry.created_at,
                  reply: entry
                )
              when Topic
                render_entry(entry, entry.created_at)
              end
            end
          end
        end
      end

      div(
        "hx-target:inherited": "#user-topics",
        "hx-swap:inherited": "outerHTML show:top showTarget:#user-topics",
        "hx-sync:inherited": "#user-topics:replace"
      ) do
        mount Shared::Pagination, pages: pages
      end
    end
  end

  private def render_entry(topic : Topic, at : Time, reply : Comment? = nil) : Nil
    article class: "px-6 py-4 transition-colors hover:bg-gray-50" do
      div class: "flex items-start justify-between gap-4" do
        h2 class: "m-0 min-w-0 text-base font-semibold break-words" do
          link topic.title, to: Forum::Show.with(id: topic.id), class: "text-[#145591] no-underline hover:underline"
        end
        span r("forum.index_page.reply_count").t(count: topic.replies_count), class: "shrink-0 text-xs leading-6 text-gray-500"
      end

      para class: "mt-2 mb-0 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-gray-500" do
        link topic.node.name, to: Forum::Index.with(node: topic.node.slug), class: "text-sky-700 no-underline hover:underline"
        local_time(
          at,
          show_replies? ? r(".replied_at").t(time: relative_time(at)) : r(".created_at").t(time: relative_time(at))
        )
      end

      if reply
        link(
          reply.withdrawn? ? r("common.comment_withdrawn").t : reply.content[0, 240],
          to: Comments::Show.with(id: reply.id),
          class: "mt-3 block line-clamp-3 text-sm leading-relaxed break-words whitespace-pre-line text-gray-700 no-underline hover:text-sky-700"
        )
      end
    end
  end
end
