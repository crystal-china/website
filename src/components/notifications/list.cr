class Notifications::List < BaseComponent
  needs notifications : NotificationQuery
  needs pages : Lucky::Paginator
  needs has_unread : Bool
  needs unread : Bool

  def render : Nil
    section class: "bg-white" do
      items = notifications.results

      if items.empty?
        para unread? ? r(".empty_unread").t : r(".empty").t, class: "m-0 px-6 py-12 text-center text-gray-500"
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

      div(
        "hx-target:inherited": "closest section",
        "hx-swap:inherited": "outerHTML show:none",
        "hx-push-url:inherited": "false"
      ) do
        mount(
          Shared::Pagination,
          pages: pages,
          classes: "flex items-center justify-center gap-4 border-t border-gray-200 p-4 text-sm"
        )
      end
    end

    tag(
      "hx-partial",
      hx_target: "#notifications-controls",
      hx_swap: "outerHTML"
    ) do
      mount(
        ::Notifications::Controls,
        has_unread: has_unread?,
        unread: unread?
      )
    end

    tag(
      "hx-partial",
      hx_target: "#notification-status",
      hx_swap: "outerHTML"
    ) do
      mount Navbar::NotificationButton, current_user: current_user
    end
  end

  private def render_notification(notification : Notification) : Nil
    unread = notification.read_at.nil?
    description = case notification.kind
                  in .topic_reply?          then r(".topic_reply").t
                  in .comment_reply?        then r(".comment_reply").t
                  in .followed_topic_reply? then r(".followed_topic_reply").t
                  in .mention?              then r(".mention").t
                  in .topic_edited?         then r(".topic_edited").t
                  in .topic_moved?          then r(".topic_moved").t
                  in .topic_deleted?        then r(".topic_deleted").t
                  in .comment_edited?       then r(".comment_edited").t
                  in .comment_deleted?      then r(".comment_deleted").t
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
    src, background = case kind
                      in .topic_reply?, .comment_reply?, .followed_topic_reply?
                        {asset("svgs/notifications/reply.svg"), "bg-sky-100"}
                      in .mention?
                        {asset("svgs/notifications/mention.svg"), "bg-amber-100"}
                      in .topic_edited?, .comment_edited?
                        {asset("svgs/notifications/edit.svg"), "bg-slate-100"}
                      in .topic_moved?
                        {asset("svgs/notifications/move.svg"), "bg-teal-100"}
                      in .topic_deleted?, .comment_deleted?
                        {asset("svgs/notifications/delete.svg"), "bg-red-100"}
                      end

    span class: "flex h-8 w-8 items-center justify-center rounded-lg #{background}" do
      img src: src, alt: "", class: "h-4 w-4"
    end
  end
end
