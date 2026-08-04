class Sidebar < BaseComponent
  def render_child(ary, this_path)
    if !ary.empty?
      expanded = ary.any? { |child| current_path.in? [this_path, child.path] } ? "block" : "hidden"

      ul class: "#{expanded} pl-5 text-base font-normal" do
        ary.each do |child|
          a_attr = {
            href: child.path,
          }

          if current_path == child.path
            # active 定义见 src/css/layout/sidebar.css
            a_attr = a_attr.merge(class: "active")
          end

          li do
            a child.name, a_attr
            render_child(child.child, child.path)
          end
        end
      end
    end
  end

  def render
    h1 "目录"

    nav do
      ul role: "nested-list" do
        PageHelpers::SIDEBAR_LINKS.each do |k, v|
          _child = v.child
          li_attr = {} of Symbol => String

          if _child.empty?
            a_name = v.name
          else
            a_name = "#{v.name}         ➤"
          end

          a_attr = {
            href: k,
          }

          if current_path == v.path
            a_attr = a_attr.merge(class: "active")
          end

          if v.parent == "root"
            li li_attr do
              a a_name, a_attr
              render_child(_child, v.path)
            end
          end
        end
      end

      if (user = current_user)
        div class: "mt-4 inline-flex items-center gap-3 rounded-full border border-gray-300 bg-white/80 px-3 py-2 shadow-sm" do
          if (avatar = user.avatar)
            img src: avatar, alt: "#{user.name} avatar", class: "h-10 w-10 rounded-full object-cover ring-1 ring-gray-200"
          else
            render_avatar_fallback(user)
          end

          render_current_user_name(user)
        end
      end
    end
  end

  private def render_current_user_name(user)
    div class: "min-w-0" do
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
