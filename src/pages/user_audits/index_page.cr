class UserAudits::IndexPage < MainLayout
  needs user : User?
  needs audits : Array(UserAudit)
  needs pages : Lucky::Paginator
  needs login_name : String
  needs kind : UserAudit::Kind?

  def page_title : String
    r("common.events").t
  end

  def page_description : String
    user ? r(".personal_description").t : r(".site_description").t
  end

  def content : Nil
    div class: "#{page_container_classes} page-content" do
      if user.nil?
        div class: "flex flex-col items-start gap-8 lg:flex-row" do
          mount Admin::Sidebar, current_user: current_user

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

    section class: "app-panel mx-auto flex max-h-[70dvh] w-full max-w-3xl flex-col overflow-hidden" do
      header class: "panel-header flex shrink-0 flex-wrap items-center justify-between gap-4" do
        div do
          h1 page_title, id: "user-audits-title", class: "panel-title"
          mount Shared::UserName, user: user if user
          para page_description, class: "panel-description"
        end

        if user
          link(
            r("common.back_to_profile").t,
            to: Users::Show.with(login_name: user.login_name),
            class: "form-secondary"
          )
        end
      end

      div(
        id: "user-audits-scroll",
        class: "min-h-0 overflow-y-auto overscroll-contain",
        role: "region",
        "aria-labelledby": "user-audits-title",
        tabindex: "0"
      ) do
        render_filters if user.nil?

        mount(
          UserAudits::List,
          audits: audits,
          pages: pages,
          show_account: user.nil?
        )
      end
    end
  end

  private def render_filters : Nil
    form(
      action: UserAudits::Index.path,
      method: "get",
      class: "grid gap-3 border-b border-gray-200 px-6 py-4 sm:grid-cols-[minmax(0,1fr)_12rem_auto]"
    ) do
      div class: "form-field" do
        label(
          r("fields.login_name").t,
          for: "audits-login-name",
          class: "form-label"
        )
        div class: "relative" do
          input(
            type: "search",
            id: "audits-login-name",
            name: "login_name",
            value: login_name,
            placeholder: r(".login_name_placeholder").t,
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
      end

      div class: "form-field" do
        label r(".event_kind").t, for: "audits-kind", class: "form-label"
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

      div class: "flex items-end" do
        button r("common.search").t, type: "submit", class: "form-submit w-full"
      end
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
