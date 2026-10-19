class Notifications::List < BaseComponent
  needs notifications : NotificationQuery
  needs pages : Lucky::Paginator
  needs has_unread : Bool

  def render : Nil
    section class: "bg-white" do
      header class: "flex justify-end border-b border-gray-200 px-4 py-3" do
        button(
          r(".read_all").t,
          type: "button",
          attrs: has_unread? ? [] of Symbol : [:disabled],
          hx_post: Notifications::ReadAll.path,
          hx_target: "closest section",
          hx_swap: "outerHTML",
          class: "form-secondary disabled:cursor-not-allowed disabled:opacity-50"
        )
      end

      items = notifications.results

      if items.empty?
        para r(".empty").t, class: "m-0 px-6 py-12 text-center text-gray-500"
      else
        items.group_by { |notification| time_in_zone(notification.created_at).date }.each_value do |group|
          date = time_in_zone(group.first.created_at)

          div do
            h3 class: "m-0 border-y border-gray-200 bg-gray-50 px-5 py-2 text-xs font-semibold tracking-wide text-gray-500" do
              time r(".date").t(time: date), datetime: date.to_s("%Y-%m-%d")
            end

            div class: "divide-y divide-gray-100" do
              group.each { |notification| render_notification(notification) }
            end
          end
        end
      end

      if pages.total > 1
        nav(
          class: "flex items-center justify-center gap-4 border-t border-gray-200 p-4",
          "aria-label": r(".pagination").t
        ) do
          if (path = pages.path_to_previous)
            render_page_link(r("common.previous_page").t, path)
          end
          span r("common.page_number").t(page: pages.page.to_s, total: pages.total.to_s), class: "text-sm text-gray-600"
          if (path = pages.path_to_next)
            render_page_link(r("common.next_page").t, path)
          end
        end
      end
    end

    tag(
      "hx-partial",
      hx_target: "#notification-status",
      hx_swap: "outerHTML"
    ) do
      mount Navbar::NotificationLink, current_user: current_user
    end
  end

  private def render_page_link(label : String, path : String) : Nil
    a(
      label,
      href: path,
      hx_get: path,
      hx_target: "closest section",
      hx_swap: "outerHTML",
      class: "form-secondary"
    )
  end

  private def render_notification(notification : Notification) : Nil
    unread = notification.read_at.nil?
    description = case notification.kind
                  in .topic_reply?     then r(".topic_reply").t
                  in .comment_reply?   then r(".comment_reply").t
                  in .mention?         then r(".mention").t
                  in .topic_edited?    then r(".topic_edited").t
                  in .topic_moved?     then r(".topic_moved").t
                  in .topic_deleted?   then r(".topic_deleted").t
                  in .comment_edited?  then r(".comment_edited").t
                  in .comment_deleted? then r(".comment_deleted").t
                  end

    # 目标可能返回 404；完整页面导航可显示提示页，而不是被 HTMX 的 noSwap 拦住。
    form_for(
      Notifications::Read.with(id: notification.id),
      hx_boost: "false"
    ) do
      button(
        type: "submit",
        class: "block w-full cursor-pointer px-5 py-4 text-left transition-colors hover:bg-sky-50 focus-visible:bg-sky-50 #{unread ? "bg-sky-50/50" : "bg-white"}"
      ) do
        span class: "flex items-start gap-3" do
          span class: "relative mt-0.5 shrink-0" do
            render_event_icon(notification.kind)
            span(
              class: "absolute -top-0.5 -right-0.5 h-2 w-2 rounded-full #{unread ? "bg-red-500 ring-2 ring-white" : "bg-transparent"}",
              "aria-label": unread ? r(".unread").t : r(".read").t
            )
          end
          span class: "min-w-0 flex-1" do
            span class: "block text-sm text-gray-900" do
              mount(
                Shared::UserName,
                user: notification.actor,
                linked: false
              )
              text " #{description}"
            end
            span notification.source_title, class: "mt-1 block truncate text-sm font-medium text-sky-700"
            span notification.excerpt, class: "line-clamp-2 mt-1 block text-xs break-words text-gray-500"
            local_time(
              notification.created_at,
              relative_time(notification.created_at),
              class: "mt-2 block text-xs text-gray-400"
            )
          end
        end
      end
    end
  end

  private def render_event_icon(kind : Notification::Kind) : Nil
    path, colors = case kind
                   in .topic_reply?, .comment_reply?
                     {"M9 6 4 11l5 5M4 11h9a7 7 0 0 1 7 7", "bg-sky-100 text-sky-700"}
                   in .mention?
                     {"M16 8v5a3 3 0 0 0 6 0v-1a10 10 0 1 0-4 8M16 12a4 4 0 1 1-8 0 4 4 0 0 1 8 0", "bg-amber-100 text-amber-700"}
                   in .topic_edited?, .comment_edited?
                     {"m16 3 5 5M4 15 16 3a2 2 0 0 1 5 5L9 20l-6 1 1-6Z", "bg-slate-100 text-slate-600"}
                   in .topic_moved?
                     {"m8 3-4 4 4 4M4 7h16m-4 6 4 4-4 4M20 17H4", "bg-teal-100 text-teal-700"}
                   in .topic_deleted?, .comment_deleted?
                     {"M3 6h18M9 6V3h6v3M5 6l1 15h12l1-15M10 10v7m4-7v7", "bg-red-100 text-red-700"}
                   end

    span(
      class: "flex h-8 w-8 items-center justify-center rounded-lg #{colors}",
      "aria-hidden": "true"
    ) do
      tag(
        "svg",
        viewBox: "0 0 24 24",
        fill: "none",
        stroke: "currentColor",
        "stroke-width": "1.75",
        "stroke-linecap": "round",
        "stroke-linejoin": "round",
        class: "h-4 w-4",
        focusable: "false"
      ) do
        tag "path", d: path
      end
    end
  end
end
