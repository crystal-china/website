class Forum::AuthorCard < BaseComponent
  needs user : User
  needs followed : Bool = false

  def render : Nil
    section class: "app-panel p-4" do
      h2 r(".author").t, class: "m-0 mb-4 text-sm font-semibold text-gray-900"

      div class: "flex items-center gap-3" do
        mount(
          Shared::Avatar,
          user: user,
          classes: "h-10 w-10 rounded-full text-sm ring-1 ring-gray-200"
        )

        div class: "min-w-0 text-sm" do
          mount(
            Shared::UserName,
            user: user,
            stacked: true
          )
        end
      end

      if (tagline = user.profile.tagline.presence)
        para tagline, class: "mt-3 mb-0 break-words text-sm leading-6 text-gray-600"
      end

      para class: "mt-4 mb-0 text-xs text-gray-500" do
        local_time(
          user.created_at,
          r(".joined").t(date: time_in_zone(user.created_at).to_s("%Y-%m-%d"))
        )
      end

      if !user.hide_online_status? && (last_active_at = user.last_active_at)
        para class: "mt-2 mb-0 text-xs text-gray-500" do
          text "#{r("common.last_active").t} "
          local_time(
            last_active_at,
            relative_time(last_active_at)
          )
        end
      end

      if (me = current_user) && me.id != user.id
        div class: "mt-4 flex justify-center [&>button]:h-8 [&>button]:rounded-lg [&>button]:px-3 [&>button]:py-0" do
          mount(
            Users::FollowButton,
            user: user,
            followed: followed?
          )
        end
      end
    end
  end
end
