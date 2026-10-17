class Users::ShowPage < MainLayout
  needs user : User

  def page_title : String
    "#{user.nickname} (@#{user.login_name})"
  end

  def page_description : String
    r(".description").t(nickname: user.nickname)
  end

  def content : Nil
    div class: "#{page_container_classes} py-10 sm:py-16" do
      article class: "app-panel mx-auto max-w-2xl overflow-hidden" do
        div class: "h-24 border-b border-sky-100 bg-gradient-to-r from-sky-100 via-slate-100 to-amber-50 sm:h-32", "aria-hidden": "true"

        div class: "px-6 pb-8 sm:px-10" do
          div class: "relative -mt-10 flex h-20 w-20 items-center justify-center overflow-hidden rounded-2xl bg-slate-800 text-3xl font-semibold text-white ring-4 ring-white" do
            text user.nickname[0].to_s.upcase

            if (avatar = user.avatar.presence)
              img src: avatar, alt: "", class: "absolute inset-0 h-full w-full object-cover", onerror: "this.remove()"
            end
          end

          header class: "mt-5 flex flex-wrap items-start justify-between gap-4" do
            div class: "min-w-0" do
              h1 class: "m-0 text-2xl font-semibold tracking-tight text-gray-900" do
                mount Shared::UserName, user: user, linked: false, stacked: true
              end
            end

            if (me = current_user) && (me.id == user.id || me.admin?)
              div class: "flex flex-wrap gap-3" do
                if me.id == user.id
                  link r("common.edit_profile").t, to: Me::Edit, class: "form-secondary"
                else
                  link r("common.edit_profile").t, to: Admin::Users::Edit.with(id: user.id), class: "form-secondary"
                end
                link r("common.events").t, to: Me::Events.with(user_id: user.id), class: "form-secondary"
              end
            end
          end

          dl class: "mt-8 border-t border-gray-100 pt-5 text-sm" do
            dt r(".joined").t, class: "text-gray-500"
            dd user.created_at.to_local.to_s("%Y-%m-%d"), class: "mt-1 ml-0 font-medium text-gray-800"

            if (last_active_at = user.last_active_at)
              dt r("common.last_active").t, class: "mt-5 text-gray-500"
              dd class: "mt-1 ml-0 font-medium text-gray-800" do
                time(
                  relative_time(last_active_at),
                  datetime: last_active_at.to_rfc3339,
                  title: last_active_at.to_local.to_s("%Y-%m-%d %H:%M:%S %z")
                )
              end
            end
          end
        end
      end
    end
  end
end
