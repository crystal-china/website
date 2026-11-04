class UserAudits::IndexPage < MainLayout
  needs user : User?
  needs audits : Array(UserAudit)
  needs pages : Lucky::Paginator
  needs login_name : String
  needs kind : UserAudit::Kind?

  def page_title : String
    r("common.account_history").t
  end

  def page_description : String
    user ? r(".personal_description").t : r(".site_description").t
  end

  def content : Nil
    div class: "#{page_container_classes} page-content" do
      if user.nil?
        div class: "flex flex-col items-start gap-8 lg:flex-row" do
          mount Admin::Sidebar

          div class: "w-full min-w-0 flex-1" do
            render_events_panel
          end
        end
      else
        render_events_panel
      end
    end
  end

  private def render_events_panel : Nil
    user = self.user
    panel_classes = user ? "app-panel mx-auto w-full max-w-3xl" : "app-panel w-full"

    section class: panel_classes do
      header class: "panel-header flex flex-wrap items-center justify-between gap-3 rounded-t-2xl px-5 py-3 sm:px-6" do
        if user
          mount Shared::UserName, user: user

          link(
            r("common.back_to_profile").t,
            to: Users::Show.with(login_name: user.login_name),
            class: "form-secondary"
          )
        else
          render_filters
        end
      end

      mount(
        UserAudits::List,
        audits: audits,
        pages: pages,
        show_account: user.nil?
      )
    end
  end

  private def render_filters : Nil
    form(
      action: UserAudits::Index.path,
      method: "get",
      class: "grid w-full grid-cols-[minmax(0,1fr)_auto] items-center gap-2 sm:w-auto sm:min-w-0 sm:flex-1 sm:grid-cols-[minmax(0,1fr)_9rem_auto]"
    ) do
      div class: "relative col-span-2 min-w-0 sm:col-span-1" do
        label(
          r("fields.login_name").t,
          for: "audits-login-name",
          class: "sr-only"
        )
        input(
          type: "search",
          id: "audits-login-name",
          name: "login_name",
          value: login_name,
          placeholder: r("fields.login_name").t,
          title: r(".login_name_placeholder").t,
          autocomplete: "off",
          data_users_autocomplete_url: Htmx::Users::Autocomplete.path,
          class: "form-input"
        )
        div(
          hidden: true,
          class: "user-autocomplete-options absolute inset-x-0 top-full z-20 mt-1 max-h-56 overflow-y-auto rounded-xl border border-gray-200 bg-white py-1 shadow-lg"
        ) do
        end
      end

      div class: "min-w-0" do
        label r(".event_kind").t, for: "audits-kind", class: "sr-only"
        select_tag(
          id: "audits-kind",
          name: "kind",
          class: "form-input"
        ) do
          option r(".all_kinds").t, value: ""

          UserAudit::Kind.each do |event_kind|
            option(
              kind_label(event_kind),
              attrs: kind == event_kind ? [:selected] : [] of Symbol,
              value: event_kind.to_s.underscore
            )
          end
        end
      end

      button r("common.search").t, type: "submit", class: "form-submit w-full"
    end
  end

  private def kind_label(kind : UserAudit::Kind) : String
    case kind
    in .profile_changed?    then r(".profile_changes").t
    in .password_changed?   then r("user_audits.list.password_changed").t
    in .oauth_signed_in?    then r("user_audits.list.oauth_signed_in").t
    in .password_removed?   then r("user_audits.list.password_removed").t
    in .password_signed_in? then r("user_audits.list.password_signed_in").t
    end
  end
end
