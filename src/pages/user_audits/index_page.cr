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
    user = self.user

    div class: "#{page_container_classes} py-10" do
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
          else
            link(
              r(".back_to_admin").t,
              to: Admin::Index,
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
end
