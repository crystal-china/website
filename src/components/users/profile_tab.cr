class Users::ProfileTab < BaseComponent
  enum Kind
    Topics
    Replies
    Following
    Followers
  end

  needs user : User
  needs entries : Array(Topic) | Array(Comment) | Array(User)
  needs pages : Lucky::Paginator
  needs tab : Kind
  needs viewer_followed_user_ids : Array(Int64)

  def render : Nil
    created_path = Users::Show.with(login_name: user.login_name).path
    replied_path = Users::Show.with(login_name: user.login_name, show_replies: true).path
    followed_users_path = Users::Show.with(login_name: user.login_name, show_followed_users: true).path
    followers_path = Users::Show.with(login_name: user.login_name, show_followers: true).path
    selected_path = case tab
                    in .topics?
                      created_path
                    in .replies?
                      replied_path
                    in .following?
                      followed_users_path
                    in .followers?
                      followers_path
                    end

    section id: "user-topics" do
      div class: "app-panel overflow-hidden" do
        div(
          class: "overflow-x-auto border-b border-gray-200 px-6 py-4 whitespace-nowrap",
          "hx-target:inherited": "#user-topics",
          "hx-swap:inherited": "outerHTML show:none",
          "hx-sync:inherited": "#user-topics:replace"
        ) do
          mount(
            Shared::Toggle,
            options: [
              {r(".created").t, created_path},
              {r(".replied").t, replied_path},
              {r(".followed_users").t, followed_users_path},
              {r(".followers").t, followers_path},
            ],
            selected: selected_path
          )
        end

        if entries.empty?
          message = case tab
                    in .topics?
                      r(".no_topics").t
                    in .replies?
                      r(".no_replies").t
                    in .following?
                      r(".no_followed_users").t
                    in .followers?
                      r(".no_followers").t
                    end

          para message, class: "m-0 px-6 py-10 text-center text-sm text-gray-500"
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
              when User
                render_user(entry)
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

  private def render_user(listed_user : User) : Nil
    article class: "flex items-center justify-between gap-4 px-6 py-4" do
      div class: "flex min-w-0 items-center gap-3" do
        mount(
          Shared::Avatar,
          user: listed_user,
          classes: "h-10 w-10 rounded-full text-sm ring-1 ring-gray-200"
        )

        div class: "min-w-0 text-sm" do
          mount(
            Shared::UserName,
            user: listed_user
          )

          if (tagline = listed_user.profile.tagline.presence)
            para tagline, class: "mt-1 mb-0 truncate text-xs text-gray-500"
          end
        end
      end

      div class: "shrink-0 [&>button]:h-8 [&>button]:px-3 [&>button]:py-0" do
        mount(
          Users::FollowButton,
          user: listed_user,
          followed: listed_user.id.in?(viewer_followed_user_ids)
        )
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
          tab.replies? ? r(".replied_at").t(time: relative_time(at)) : r(".created_at").t(time: relative_time(at))
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
