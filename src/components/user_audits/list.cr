class UserAudits::List < BaseComponent
  needs audits : Array(UserAudit)
  needs pages : Lucky::Paginator
  needs show_account : Bool = false

  def render : Nil
    if audits.empty?
      para r(".empty").t, class: "m-0 px-6 py-10 text-center text-gray-500"
    else
      ol class: "m-0 list-none divide-y divide-gray-200 p-0" do
        audits.each do |audit|
          li class: "px-6 py-5" do
            if show_account?
              para class: "mt-0 mb-3 text-sm text-gray-600" do
                text r(".account").t

                render_account(audit.user, audit.user_id)
              end
            end

            render_event(audit)
            para class: "mt-2 mb-0 text-xs text-gray-500" do
              text r(".actor").t

              render_account(audit.actor, audit.actor_id)
            end
            local_time(
              audit.created_at,
              relative_time(audit.created_at),
              class: "mt-2 block text-xs text-gray-500"
            )
          end
        end
      end
    end

    mount(
      Shared::Pagination,
      pages: pages,
      classes: "flex items-center justify-center gap-4 border-t border-gray-200 px-6 py-4 text-sm"
    )
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

  private def render_event(audit : UserAudit) : Nil
    case audit.kind
    when .profile_changed?
      h2(
        r(".profile_changed").t(
          field: ValidationErrors.field_name(audit.changed_column_name.not_nil!)
        ),
        class: "m-0 text-sm font-medium text-gray-900"
      )
      para class: "mt-2 mb-0 text-sm break-words text-gray-600" do
        text audit.from.presence || r("common.unset").t
        text " → "
        text audit.to.presence || r("common.unset").t
      end
    when .password_changed?
      h2 r(".password_changed").t, class: "m-0 text-sm font-medium text-gray-900"
      para r(".password_privacy").t, class: "mt-2 mb-0 text-sm text-gray-600"
    when .password_signed_in?
      h2 r(".password_signed_in").t, class: "m-0 text-sm font-medium text-gray-900"
    when .oauth_signed_in?
      h2 r(".oauth_signed_in").t, class: "m-0 text-sm font-medium text-gray-900"
      para r(".oauth_provider").t(provider: audit.oauth_provider.to_s), class: "mt-2 mb-0 text-sm text-gray-600"
    when .password_removed?
      h2 r(".password_removed").t, class: "m-0 text-sm font-medium text-gray-900"
      para r(".password_removed_description").t, class: "mt-2 mb-0 text-sm text-gray-600"
    end
  end
end
