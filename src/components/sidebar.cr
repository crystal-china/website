class Sidebar < BaseComponent
  def render_child(ary, this_path)
    if !ary.empty?
      expanded = ary.any? { |child| current_path.in? [this_path, child.path] } ? "block" : "hidden"

      ul class: "#{expanded} pl-5" do
        ary.each do |child|
          a_attr = {
            href: child.path,
          }

          if current_path == child.path
            # active 定义见 src/css/components/sidebar.css
            a_attr = a_attr.merge(class: "active")
          end

          li do
            a child.title, a_attr
            render_child(child.children, child.path)
          end
        end
      end
    end
  end

  def render
    h1 "目录", class: "my-4 text-[2em] leading-tight font-bold tracking-tight"

    nav do
      ul role: "nested-list" do
        DocNavigation.navigation.each do |page|
          children = page.children

          if children.empty?
            link_title = page.title
          else
            link_title = "#{page.title}         ➤"
          end

          a_attr = {
            href: page.path,
          }

          if current_path == page.path
            a_attr = a_attr.merge(class: "active")
          end

          li do
            a link_title, a_attr
            render_child(children, page.path)
          end
        end
      end
    end

    render_current_user
  end

  private def render_current_user
    return unless (user = current_user)

    div class: "mt-4 inline-flex items-center gap-3 rounded-full border border-gray-300 bg-white/80 px-3 py-2 shadow-sm" do
      if (avatar = user.avatar).presence
        div class: "relative h-10 w-10 shrink-0" do
          render_avatar_fallback(user)
          img(
            src: avatar.not_nil!,
            alt: "",
            class: "absolute inset-0 h-10 w-10 rounded-full object-cover ring-1 ring-gray-200",
            onerror: "this.remove()"
          )
        end
      else
        render_avatar_fallback(user)
      end

      render_current_user_name(user)
    end
  end

  private def render_current_user_name(user)
    div class: "min-w-0 space-y-1" do
      div "当前用户", class: "text-xs tracking-wide text-gray-500"
      strong user.name, class: "block truncate text-sm font-semibold text-gray-900"
    end
  end

  private def render_avatar_fallback(user)
    div class: "flex h-10 w-10 items-center justify-center rounded-full bg-gray-900 text-sm font-semibold text-white" do
      text user.name[0].to_s.upcase
    end
  end
end
