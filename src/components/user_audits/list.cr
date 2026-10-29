class UserAudits::List < BaseComponent
  needs audits : Array(UserAudit)
  needs pages : Lucky::Paginator
  needs show_account : Bool = false

  def render : Nil
    section id: "user-audits-list" do
      render_audits

      # 只让分页链接继承局部刷新，记录中的用户链接仍走整页导航。
      div(
        "hx-target:inherited": "#user-audits-list",
        "hx-swap:inherited": "outerHTML show:top showTarget:body",
        "hx-sync:inherited": "#user-audits-list:replace"
      ) do
        mount(
          Shared::Pagination,
          pages: pages,
          classes: "flex items-center justify-center gap-4 border-t border-gray-200 px-6 py-4 text-sm"
        )
      end
    end
  end

  private def render_audits : Nil
    if audits.empty?
      para r(".empty").t, class: "m-0 px-6 py-10 text-center text-gray-500"
    else
      ol class: "m-0 list-none divide-y divide-gray-200 p-0" do
        audits.each do |audit|
          li class: "flex items-start gap-3 px-5 py-3 text-sm sm:px-6" do
            if show_account? && (user = audit.user)
              mount(
                Shared::Avatar,
                user: user,
                classes: "h-8 w-8 rounded-full text-sm"
              )
            end

            div class: "flex min-w-0 flex-1 items-start justify-between gap-3" do
              div class: "flex min-w-0 flex-wrap items-baseline gap-x-2 gap-y-1" do
                if show_account?
                  render_account(audit.user, audit.user_id)
                  span "·", class: "text-gray-300"
                end

                h2 event_title(audit), class: "m-0 text-sm leading-5 font-medium text-gray-900"

                render_event_details(audit)

                if audit.actor_id.nil? || audit.actor_id != audit.user_id
                  span class: "text-xs text-gray-500" do
                    text r(".actor").t

                    render_account(audit.actor, audit.actor_id)
                  end
                end
              end

              local_time(
                audit.created_at,
                relative_time(audit.created_at),
                class: "shrink-0 text-xs leading-5 whitespace-nowrap text-gray-500"
              )
            end
          end
        end
      end
    end
  end

  private def render_account(user : User?, id : Int64?) : Nil
    if user
      mount Shared::UserName, user: user
    elsif id
      text r(".unknown_account_id").t(id: id.to_s)
    else
      text r(".unknown_account").t
    end
  end

  private def event_title(audit : UserAudit) : String
    case audit.kind
    in .profile_changed?
      r(".profile_changed").t(
        field: ValidationErrors.field_name(audit.changed_column_name.not_nil!)
      )
    in .password_changed?   then r(".password_changed").t
    in .password_signed_in? then r(".password_signed_in").t
    in .oauth_signed_in?    then r(".oauth_provider").t(provider: audit.oauth_provider.to_s)
    in .password_removed?   then r(".password_removed").t
    end
  end

  private def render_event_details(audit : UserAudit) : Nil
    case audit.kind
    when .profile_changed?
      span class: "text-sm break-words text-gray-600" do
        text audit.from.presence || r("common.unset").t
        text " → "
        text audit.to.presence || r("common.unset").t
      end
    end
  end
end
