class Forum::AuthorCard < BaseComponent
  needs user : User

  def render : Nil
    section class: "app-panel p-4" do
      h2 r(".author").t, class: "m-0 mb-4 text-sm font-semibold text-gray-900"

      div class: "flex items-center gap-3" do
        div class: "relative h-10 w-10 shrink-0" do
          span user.nickname[0].to_s.upcase, class: "flex h-10 w-10 items-center justify-center rounded-full bg-gray-900 text-sm font-semibold text-white"

          if (avatar = user.avatar.presence)
            img(
              src: avatar,
              alt: "",
              class: "absolute inset-0 h-10 w-10 rounded-full object-cover ring-1 ring-gray-200",
              onerror: "this.remove()"
            )
          end
        end

        div class: "min-w-0 text-sm" do
          mount Shared::UserName, user: user, stacked: true
        end
      end

      para r(".joined").t(date: user.created_at.to_local.to_s("%Y-%m-%d")), class: "mt-4 mb-0 text-xs text-gray-500"

      if (last_active_at = user.last_active_at)
        para class: "mt-2 mb-0 text-xs text-gray-500" do
          text "#{r("common.last_active").t} "
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
