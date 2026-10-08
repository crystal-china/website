class Forum::AuthorCard < BaseComponent
  needs user : User

  def render
    section class: "app-panel p-4" do
      h2 "主题作者", class: "m-0 mb-4 text-sm font-semibold text-gray-900"

      div class: "flex items-center gap-3" do
        div class: "relative h-10 w-10 shrink-0" do
          span user.name[0].to_s.upcase, class: "flex h-10 w-10 items-center justify-center rounded-full bg-gray-900 text-sm font-semibold text-white"

          if (avatar = user.avatar.presence)
            img(
              src: avatar,
              alt: "",
              class: "absolute inset-0 h-10 w-10 rounded-full object-cover ring-1 ring-gray-200",
              onerror: "this.remove()"
            )
          end
        end

        strong user.name, class: "min-w-0 break-words text-sm font-semibold text-gray-900"
      end

      para "加入于 #{user.created_at.to_local.to_s("%Y-%m-%d")}", class: "mt-4 mb-0 text-xs text-gray-500"
    end
  end
end
