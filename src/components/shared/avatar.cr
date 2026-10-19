class Shared::Avatar < BaseComponent
  # 按用户 ID 固定选色，刷新、改名和重启不会改变同一账号的颜色。
  BACKGROUNDS = {"bg-sky-700", "bg-teal-700", "bg-emerald-700", "bg-amber-700", "bg-rose-700", "bg-slate-700"}

  needs user : User
  needs classes : String

  def render : Nil
    span(
      class: "user-avatar relative flex shrink-0 items-center justify-center overflow-hidden font-semibold text-white #{BACKGROUNDS[user.id % BACKGROUNDS.size]} #{classes}",
      "aria-hidden": "true"
    ) do
      text (user.nickname.presence || user.login_name)[0].to_s.upcase

      if (avatar = user.avatar.presence)
        img(
          src: avatar,
          alt: "",
          class: "absolute inset-0 h-full w-full bg-white object-cover",
          onerror: "this.remove()"
        )
      end
    end
  end
end
