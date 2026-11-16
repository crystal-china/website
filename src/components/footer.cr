class Footer < BaseComponent
  def render : Nil
    space = context.site_space
    contact_email = space.try(&.contact_email) || Space::DEFAULT_CONTACT_EMAIL
    footer_links = space.try(&.footer_links) || Space::DEFAULT_FOOTER_LINKS

    footer class: "mt-12" do
      hr class: "mx-auto my-1 w-[70%] max-w-4xl border-t border-gray-300"

      section class: "#{page_container_classes} mt-2 flex flex-wrap items-center justify-center gap-x-3 gap-y-2 text-sm" do
        unless contact_email.blank?
          address class: "not-italic" do
            text r(".contact").t
            a(
              contact_email,
              href: "mailto:#{contact_email}",
              class: "text-sky-700 hover:text-sky-900 hover:underline"
            )
          end
        end

        span(
          id: "online-users-status",
          # 停留在页面时保持在线登记，并定时更新通知状态。
          hx_trigger: "load, every 2m",
          hx_patch: Htmx::Heartbeat.path,
        ) do
          text r(".counting").t
        end

        unless footer_links.empty?
          nav "aria-label": r(".links").t, class: "inline-flex items-center gap-3" do
            footer_links.each do |link|
              icon_link(
                title: link.title,
                href: link.url,
                src: Space.image_url(link.icon),
                alt: link.title
              )
            end
          end
        end
      end

      mount ::OnlineUsers::Dialog if current_user
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
        class: "h-5 w-5 object-contain"
      )
    end
  end
end
