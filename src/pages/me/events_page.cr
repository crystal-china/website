class Me::EventsPage < MainLayout
  needs user : User
  needs audits : Array(UserAudit)
  needs pages : Lucky::Paginator

  def page_title : String
    "账户记录"
  end

  def content : Nil
    time_in_words = TimeInWords::Helpers(TimeInWords::I18n::ZH_CN)

    div class: "#{page_container_classes} py-10" do
      section class: "app-panel mx-auto w-full max-w-3xl overflow-hidden" do
        header class: "panel-header flex flex-wrap items-center justify-between gap-4" do
          div do
            h1 page_title, class: "panel-title"
            mount Shared::UserName, user: user
            para "记录个人资料修改、密码修改和第三方登录。", class: "panel-description"
          end

          link "回到主页", to: Users::Show.with(login_name: user.login_name), class: "form-secondary"
        end

        if audits.empty?
          para "暂无账户记录。", class: "m-0 px-6 py-10 text-center text-gray-500"
        else
          ol class: "m-0 list-none divide-y divide-gray-200 p-0" do
            audits.each do |audit|
              li class: "px-6 py-5" do
                render_event(audit)
                para class: "mt-2 mb-0 text-xs text-gray-500" do
                  text "操作人："

                  if (actor = audit.actor)
                    mount Shared::UserName, user: actor
                  else
                    text "未知或账号已删除"
                  end
                end
                time(
                  time_in_words.from(past_time: audit.created_at),
                  datetime: audit.created_at.to_rfc3339,
                  title: audit.created_at.to_local.to_s("%Y-%m-%d %H:%M:%S %z"),
                  class: "mt-2 block text-xs text-gray-500"
                )
              end
            end
          end
        end

        render_pagination unless pages.one_page?
      end
    end
  end

  private def render_event(audit : UserAudit) : Nil
    case audit.kind
    when .profile_changed?
      h2 "修改#{ValidationErrors.field_name(audit.changed_column_name.not_nil!)}", class: "m-0 text-sm font-medium text-gray-900"
      para class: "mt-2 mb-0 break-words text-sm text-gray-600" do
        text audit.from.presence || "未设置"
        text " → "
        text audit.to.presence || "未设置"
      end
    when .password_changed?
      h2 "修改密码", class: "m-0 text-sm font-medium text-gray-900"
      para "仅记录修改时间，不保存密码或密码哈希。", class: "mt-2 mb-0 text-sm text-gray-600"
    when .oauth_signed_in?
      h2 "第三方登录", class: "m-0 text-sm font-medium text-gray-900"
      para "通过 #{audit.provider} 登录。", class: "mt-2 mb-0 text-sm text-gray-600"
    when .password_removed?
      h2 "移除本站密码", class: "m-0 text-sm font-medium text-gray-900"
      para "密码登录已禁用，已有登录会话已失效。", class: "mt-2 mb-0 text-sm text-gray-600"
    end
  end

  private def render_pagination : Nil
    nav class: "flex items-center justify-center gap-4 border-t border-gray-200 px-6 py-4 text-sm", "aria-label": "账户记录分页" do
      if (previous_path = pages.path_to_previous)
        a "上一页", href: previous_path, class: "form-secondary"
      end

      span "第 #{pages.page} / #{pages.total} 页", class: "text-gray-600"

      if (next_path = pages.path_to_next)
        a "下一页", href: next_path, class: "form-secondary"
      end
    end
  end
end
