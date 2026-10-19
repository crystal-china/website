class Users::ShowPage < MainLayout
  needs user : User

  def page_title : String
    "#{user.nickname} (@#{user.login_name})"
  end

  def page_description : String
    r(".description").t(nickname: user.nickname)
  end

  def content : Nil
    online_hours, online_minutes = (user.online_seconds // 60).divmod(60)

    div class: "#{page_container_classes} py-10 sm:py-16" do
      article class: "app-panel mx-auto max-w-2xl overflow-hidden" do
        div(
          class: "h-24 border-b border-sky-100 bg-gradient-to-r from-sky-100 via-slate-100 to-amber-50 sm:h-32",
          "aria-hidden": "true"
        )

        div class: "px-6 pb-8 sm:px-10" do
          mount(
            Shared::Avatar,
            user: user,
            classes: "-mt-10 h-20 w-20 rounded-2xl text-3xl ring-4 ring-white"
          )

          header class: "mt-5 flex flex-wrap items-start justify-between gap-4" do
            div class: "min-w-0" do
              h1 class: "m-0 text-2xl font-semibold tracking-tight text-gray-900" do
                mount(
                  Shared::UserName,
                  user: user,
                  linked: false,
                  stacked: true
                )
              end

              if (tagline = user.profile.tagline.presence)
                para tagline, class: "mt-2 mb-0 break-words text-sm text-gray-500"
              end
            end

            if (me = current_user) && (me.id == user.id || me.admin?)
              div class: "flex flex-wrap gap-3" do
                link(
                  r("common.edit_profile").t,
                  to: Users::Edit.with(id: user.id),
                  class: "form-secondary"
                )
                link(
                  r("common.events").t,
                  to: Me::Events.with(user_id: user.id),
                  class: "form-secondary"
                )
              end
            end
          end

          if (bio = user.profile.bio.presence)
            section class: "mt-8 border-t border-gray-100 pt-5" do
              h2 r("fields.bio").t, class: "m-0 text-sm font-medium text-gray-500"
              para bio, class: "mt-2 mb-0 whitespace-pre-line break-words text-sm leading-7 text-gray-700"
            end
          end

          dl class: "mt-8 border-t border-gray-100 pt-5 text-sm" do
            dt r(".joined").t, class: "text-gray-500"
            dd class: "mt-1 ml-0 font-medium text-gray-800" do
              local_time(
                user.created_at,
                time_in_zone(user.created_at).to_s("%Y-%m-%d")
              )
            end

            unless user.hide_online_status?
              if (last_active_at = user.last_active_at)
                dt r("common.last_active").t, class: "mt-5 text-gray-500"
                dd class: "mt-1 ml-0 font-medium text-gray-800" do
                  local_time(
                    last_active_at,
                    relative_time(last_active_at)
                  )
                end
              end

              dt r(".online_time").t, class: "mt-5 text-gray-500"
              dd(
                r(".online_duration").t(hours: online_hours.to_s, minutes: online_minutes.to_s),
                class: "mt-1 ml-0 font-medium text-gray-800"
              )
            end
          end
        end
      end
    end
  end
end
