class Me::EventsPage < MainLayout
  needs user : User
  needs audits : Array(UserAudit)
  needs pages : Lucky::Paginator

  def page_title : String
    r("common.events").t
  end

  def content : Nil
    div class: "#{page_container_classes} py-10" do
      section class: "app-panel mx-auto w-full max-w-3xl overflow-hidden" do
        header class: "panel-header flex flex-wrap items-center justify-between gap-4" do
          div do
            h1 page_title, class: "panel-title"
            mount Shared::UserName, user: user
            para r(".description").t, class: "panel-description"
          end

          link r("common.back_to_profile").t, to: Users::Show.with(login_name: user.login_name), class: "form-secondary"
        end

        if audits.empty?
          para r(".empty").t, class: "m-0 px-6 py-10 text-center text-gray-500"
        else
          ol class: "m-0 list-none divide-y divide-gray-200 p-0" do
            audits.each do |audit|
              li class: "px-6 py-5" do
                render_event(audit)
                para class: "mt-2 mb-0 text-xs text-gray-500" do
                  text r(".actor").t

                  if (actor = audit.actor)
                    mount Shared::UserName, user: actor
                  else
                    text r(".unknown_actor").t
                  end
                end
                time(
                  relative_time(audit.created_at),
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
      h2 r(".profile_changed").t(field: ValidationErrors.field_name(audit.changed_column_name.not_nil!)), class: "m-0 text-sm font-medium text-gray-900"
      para class: "mt-2 mb-0 break-words text-sm text-gray-600" do
        text audit.from.presence || r("common.unset").t
        text " → "
        text audit.to.presence || r("common.unset").t
      end
    when .password_changed?
      h2 r(".password_changed").t, class: "m-0 text-sm font-medium text-gray-900"
      para r(".password_privacy").t, class: "mt-2 mb-0 text-sm text-gray-600"
    when .oauth_signed_in?
      h2 r(".oauth_signed_in").t, class: "m-0 text-sm font-medium text-gray-900"
      para r(".oauth_provider").t(provider: audit.provider.to_s), class: "mt-2 mb-0 text-sm text-gray-600"
    when .password_removed?
      h2 r(".password_removed").t, class: "m-0 text-sm font-medium text-gray-900"
      para r(".password_removed_description").t, class: "mt-2 mb-0 text-sm text-gray-600"
    end
  end

  private def render_pagination : Nil
    nav class: "flex items-center justify-center gap-4 border-t border-gray-200 px-6 py-4 text-sm", "aria-label": r(".pagination").t do
      if (previous_path = pages.path_to_previous)
        a r("common.previous_page").t, href: previous_path, class: "form-secondary"
      end

      span r("common.page_number").t(page: pages.page.to_s, total: pages.total.to_s), class: "text-gray-600"

      if (next_path = pages.path_to_next)
        a r("common.next_page").t, href: next_path, class: "form-secondary"
      end
    end
  end
end
