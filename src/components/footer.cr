class Footer < BaseComponent
  def render : Nil
    footer class: "mt-12" do
      hr class: "mx-auto my-1 w-[70%] max-w-4xl border-t border-gray-300"

      section class: "#{page_container_classes} mt-2 flex flex-wrap items-center justify-center gap-x-3 gap-y-2 text-sm" do
        address class: "not-italic" do
          text r(".contact").t
          a(
            "admin@crystal-china.org",
            href: "mailto:admin@crystal-china.org",
            class: "text-sky-700 hover:text-sky-900 hover:underline"
          )
        end

        span(
          # 停留在页面时保持在线登记，并定时更新通知状态。
          hx_trigger: "load, every 2m",
          hx_patch: Htmx::OnlineUsers.path,
        ) do
          text r(".counting").t
        end

        nav "aria-label": r(".links").t, class: "inline-flex items-center gap-3" do
          icon_link(
            title: r(".github").t,
            href: "https://github.com/crystal-china",
            src: asset("svgs/github-icon.svg"),
            alt: "github"
          )
          icon_link(
            title: r(".x_account").t,
            href: "https://x.com/crystalchinaorg",
            src: asset("svgs/x-icon.svg"),
            alt: "x.com"
          )
          icon_link(
            title: r(".official_site").t,
            href: "https://crystal-lang.org/",
            src: asset("svgs/crystal-lang-icon.svg"),
            alt: "crystal-lang"
          )
        end
      end
    end
  end

  private def icon_link(title, href, src, alt) : Nil
    a(
      href: href,
      target: "_blank",
      rel: "nofollow",
      title: title,
      class: "inline-flex items-center"
    ) do
      img(
        src: src,
        alt: alt,
        class: "h-5 w-5"
      )
    end
  end
end
