class Pager < BaseComponent
  include PageHelpers

  def render
    div class: "flex flex-wrap items-center justify-between gap-4 pt-[3em]" do
      pages = DocNavigation.pages
      current_idx = pages.index { |page| page.path == current_path }

      return unless current_idx

      prev_idx = [current_idx - 1, 0].max
      next_idx = [current_idx + 1, pages.size - 1].min
      current_page = pages[current_idx]
      prev_page = pages[prev_idx]
      next_page = pages[next_idx]

      div class: "flex w-full items-center sm:w-auto" do
        img src: asset("svgs/previous_page.svg"), alt: "previous_page", class: "h-[24px]"

        strong class: "ml-2" do
          if prev_page.path == current_page.path
            text "没有上一页了"
          else
            a prev_page.title, href: prev_page.path
          end
        end
      end

      strong class: "w-full text-center text-xl sm:w-auto" do
        text current_page.title
      end

      div class: "flex w-full items-center justify-end sm:w-auto" do
        strong class: "mr-2" do
          if next_page.path == current_page.path
            text "没有下一页了"
          else
            a next_page.title, href: next_page.path
          end
        end
        img src: asset("svgs/next_page.svg"), alt: "next_page", class: "h-[24px]"
      end
    end
  end
end
