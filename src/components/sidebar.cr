class Sidebar < BaseComponent
  def render_child(ary, this_path) : Nil
    if !ary.empty?
      expanded = (current_path == this_path || contains_current_path?(ary)) ? "block" : "hidden"

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

  private def contains_current_path?(pages) : Bool
    pages.any? do |page|
      current_path == page.path || contains_current_path?(page.children)
    end
  end

  def render : Nil
    h1 r(".title").t, class: "my-4 text-[2em] leading-tight font-bold tracking-tight"

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
  end
end
