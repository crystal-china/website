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
        div class: "divide-y divide-gray-200" do
          items.each { |notification| render_notification(notification) }
        end
      end

      if pages.total > 1
        nav class: "flex items-center justify-center gap-4 border-t border-gray-200 p-4", "aria-label": r(".pagination").t do
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
    form_for Notifications::Read.with(id: notification.id), hx_boost: "false" do
      button type: "submit", class: "block w-full cursor-pointer px-5 py-4 text-left transition-colors hover:bg-sky-50 focus-visible:bg-sky-50 #{unread ? "bg-sky-50/50" : "bg-white"}" do
        span class: "flex items-start gap-3" do
          span class: "mt-2 h-2 w-2 shrink-0 rounded-full #{unread ? "bg-red-500" : "bg-transparent"}", "aria-label": unread ? r(".unread").t : r(".read").t
          span class: "min-w-0 flex-1" do
            span class: "block text-sm text-gray-900" do
              mount Shared::UserName, user: notification.actor, linked: false
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
end
