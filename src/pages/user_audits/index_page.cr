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

    div class: "#{page_container_classes} pb-10" do
      section class: "mx-auto w-full max-w-3xl" do
        header class: "sticky top-0 z-[60] bg-[#F4F6F8] pt-10 lg:top-[var(--navbar-height)] lg:z-40" do
          div class: "app-panel panel-header flex flex-wrap items-center justify-between gap-4 rounded-b-none" do
            div do
              h1 page_title, class: "panel-title"
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
        end

        div class: "app-panel rounded-t-none border-t-0 shadow-none" do
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
