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

          link(
            r("common.back_to_profile").t,
            to: Users::Show.with(login_name: user.login_name),
            class: "form-secondary"
          )
        end

        mount(
          UserAudits::List,
          audits: audits,
          pages: pages
        )
      end
    end
  end
end
