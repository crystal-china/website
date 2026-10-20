class UserAudits::IndexPage < MainLayout
  needs user : User?
  needs audits : Array(UserAudit)
  needs pages : Lucky::Paginator

  def page_title : String
    r("common.events").t
  end

  def page_description : String
    user ? r(".personal_description").t : r(".site_description").t
  end

  def content : Nil
    div class: "#{page_container_classes} py-10" do
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
        class: "min-h-0 overflow-y-auto overscroll-contain",
        role: "region",
        "aria-labelledby": "user-audits-title",
        tabindex: "0"
      ) do
        mount(
          UserAudits::List,
          audits: audits,
          pages: pages,
          show_account: user.nil?
        )
      end
    end
  end
end
