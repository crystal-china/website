class Footer < BaseComponent
  def render
    hr class: "mx-auto my-1 w-[70%] max-w-4xl border-t border-gray-300"

    section class: "#{page_container_classes} mt-2 flex flex-wrap items-center justify-center gap-x-3 gap-y-2 text-sm" do
      address class: "not-italic" do
        text "Crystal China "
        a "admin@crystal-china.org", href: "mailto:admin@crystal-china.org"
      end

      span(
        hx_trigger: "load,every 2m",
        hx_patch: Htmx::OnlineUsers.with(user_id: current_user.try(&.id)).path,
        hx_include: "[name='_csrf']",
      ) do
        text "在线用户 #{ONLINE_USER_COUNTER.keys.size} 人, 游客 #{ONLINE_IP_COUNTER.keys.size} 人"
      end

      nav "aria-label": "页脚链接", class: "inline-flex items-center gap-3" do
        icon_link(
          title: "本站在 GitHub 上面的开源内容",
          href: "https://github.com/crystal-china",
          src: asset("svgs/github-icon.svg"),
          alt: "github"
        )
        icon_link(
          title: "本站的 X 账号",
          href: "https://x.com/crystalchinaorg",
          src: asset("svgs/x-icon.svg"),
          alt: "x.com"
        )
        icon_link(
          title: "Crystal 官方网站",
          href: "https://crystal-lang.org/",
          src: asset("svgs/crystal-lang-icon.svg"),
          alt: "crystal-lang"
        )
      end
    end
  end

  private def icon_link(title, href, src, alt)
    a href: href, target: "_blank", rel: "nofollow", title: title, class: "inline-flex items-center" do
      img src: src, alt: alt, class: "h-5 w-5"
    end
  end
end
