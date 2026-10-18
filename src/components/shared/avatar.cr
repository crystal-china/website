class Shared::Avatar < BaseComponent
  needs user : User
  needs classes : String

  def render : Nil
    span(
      class: "user-avatar relative flex shrink-0 items-center justify-center overflow-hidden bg-slate-800 font-semibold text-white #{classes}",
      "aria-hidden": "true"
    ) do
      text (user.nickname.presence || user.login_name)[0].to_s.upcase

      if (avatar = user.avatar.presence)
        img(
          src: avatar,
          alt: "",
          class: "absolute inset-0 h-full w-full object-cover",
          onerror: "this.remove()"
        )
      end
    end
  end
end
