class Notifications::IndexPage < MainLayout
  needs notifications : NotificationQuery
  needs pages : Lucky::Paginator

  def page_title
    "通知"
  end

  def content
    div class: "#{page_container_classes} py-8 sm:py-10" do
      section class: "mx-auto max-w-3xl" do
        header class: "mb-6 flex flex-wrap items-center justify-between gap-4" do
          h1 "通知", class: "m-0 text-2xl font-semibold text-gray-900"
          form_for Notifications::ReadAll do
            submit "全部标为已读", class: "form-secondary"
          end
        end

        items = notifications.results
        if items.empty?
          para "还没有通知。有人回复或提及你时，会显示在这里。", class: "app-panel m-0 px-6 py-12 text-center text-gray-500"
        else
          div class: "app-panel divide-y divide-gray-200 overflow-hidden" do
            items.each { |notification| render_notification(notification) }
          end
        end

        unless pages.one_page?
          nav class: "mt-6 flex items-center justify-center gap-4", "aria-label": "通知分页" do
            if (path = pages.path_to_previous)
              a "上一页", href: path, class: "form-secondary"
            end
            span "第 #{pages.page} / #{pages.total} 页", class: "text-sm text-gray-600"
            if (path = pages.path_to_next)
              a "下一页", href: path, class: "form-secondary"
            end
          end
        end
      end
    end
  end

  private def render_notification(notification : Notification)
    unread = notification.read_at.nil?
    visible = notification.target_visible?
    description = case notification.kind
                  when "topic_reply"   then "回复了你的主题"
                  when "comment_reply" then "回复了你的评论"
                  else                      "提及了你"
                  end

    form_for Notifications::Read.with(id: notification.id) do
      button type: "submit", class: "block w-full cursor-pointer px-5 py-4 text-left transition-colors hover:bg-sky-50 focus-visible:bg-sky-50 #{unread ? "bg-sky-50/50" : "bg-white"}" do
        span class: "flex items-start gap-3" do
          span class: "mt-2 h-2 w-2 shrink-0 rounded-full #{unread ? "bg-red-500" : "bg-transparent"}", "aria-label": unread ? "未读" : "已读"
          span class: "min-w-0 flex-1" do
            span class: "block text-sm text-gray-900" do
              strong notification.actor.name
              text " #{description}"
            end
            if visible
              span notification.source_title, class: "mt-1 block truncate text-sm font-medium text-sky-700"
              if (comment = notification.comment)
                span comment.content[0, 120], class: "mt-1 block line-clamp-2 break-words text-xs text-gray-500"
              end
            else
              span "相关内容已删除或暂不可见", class: "mt-1 block text-sm text-gray-500"
            end
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
