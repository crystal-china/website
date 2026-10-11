class Notifications::List < BaseComponent
  needs notifications : NotificationQuery
  needs pages : Lucky::Paginator

  def render
    section class: "bg-white" do
      header class: "flex justify-end border-b border-gray-200 px-4 py-3" do
        button(
          "全部标为已读",
          type: "button",
          hx_post: Notifications::ReadAll.path,
          hx_target: "closest section",
          hx_swap: "outerHTML",
          class: "form-secondary"
        )
      end

      items = notifications.results

      if items.empty?
        para "还没有通知。有人回复或提及你时，会显示在这里。", class: "m-0 px-6 py-12 text-center text-gray-500"
      else
        div class: "divide-y divide-gray-200" do
          items.each { |notification| render_notification(notification) }
        end
      end

      if pages.total > 1
        nav class: "flex items-center justify-center gap-4 border-t border-gray-200 p-4", "aria-label": "通知分页" do
          if (path = pages.path_to_previous)
            render_page_link("上一页", path)
          end
          span "第 #{pages.page} / #{pages.total} 页", class: "text-sm text-gray-600"
          if (path = pages.path_to_next)
            render_page_link("下一页", path)
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

  private def render_page_link(label : String, path : String)
    a(
      label,
      href: path,
      hx_get: path,
      hx_target: "closest section",
      hx_swap: "outerHTML",
      class: "form-secondary"
    )
  end

  private def render_notification(notification : Notification)
    unread = notification.read_at.nil?
    description = case notification.kind
                  in .topic_reply?     then "回复了你的主题"
                  in .comment_reply?   then "回复了你的评论"
                  in .mention?         then "提及了你"
                  in .topic_edited?    then "编辑了你的主题"
                  in .topic_moved?     then "移动了你的主题"
                  in .topic_deleted?   then "删除了你的主题"
                  in .comment_edited?  then "编辑了你的评论"
                  in .comment_deleted? then "删除了你的评论"
                  end

    # 目标可能返回 404；完整页面导航可显示提示页，而不是被 HTMX 的 noSwap 拦住。
    form_for Notifications::Read.with(id: notification.id), hx_boost: "false" do
      button type: "submit", class: "block w-full cursor-pointer px-5 py-4 text-left transition-colors hover:bg-sky-50 focus-visible:bg-sky-50 #{unread ? "bg-sky-50/50" : "bg-white"}" do
        span class: "flex items-start gap-3" do
          span class: "mt-2 h-2 w-2 shrink-0 rounded-full #{unread ? "bg-red-500" : "bg-transparent"}", "aria-label": unread ? "未读" : "已读"
          span class: "min-w-0 flex-1" do
            span class: "block text-sm text-gray-900" do
              strong notification.actor.name
              text " #{description}"
            end
            span notification.source_title, class: "mt-1 block truncate text-sm font-medium text-sky-700"
            span notification.excerpt, class: "line-clamp-2 mt-1 block text-xs break-words text-gray-500"
            span(
              TimeInWords::Helpers(TimeInWords::I18n::ZH_CN).from(past_time: notification.created_at),
              class: "mt-2 block text-xs text-gray-400",
              title: notification.created_at.to_local.to_s("%Y-%m-%d %H:%M:%S")
            )
          end
        end
      end
    end
  end
end
