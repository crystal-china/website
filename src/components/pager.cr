class Pager < BaseComponent
  include PageHelpers

  def render
    div class: "flex items-center justify-between pt-[3em]" do
      item = PAGINATION_RELATION_MAPPING[current_path]?
      current_idx = PAGINATION_URLS.index(current_path)

      return unless current_idx

      prev_idx = [current_idx - 1, 0].max
      next_idx = [current_idx + 1, PAGINATION_URLS.size - 1].min
      prev_path = PAGINATION_URLS[prev_idx]
      next_path = PAGINATION_URLS[next_idx]

      if item
        div class: "flex items-center" do
          img src: asset("svgs/previous_page.svg"), alt: "previous_page", class: "h-[24px]"

          strong class: "ml-2" do
            if prev_path == current_path
              text "没有上一页了"
            else
              a PAGINATION_RELATION_MAPPING[prev_path][:title], href: prev_path
            end
          end
        end

        strong class: "text-xl" do
          text item[:title]
        end

        div class: "flex items-center" do
          strong class: "mr-2" do
            if next_path == current_path
              text "没有下一页了"
            else
              a PAGINATION_RELATION_MAPPING[next_path][:title], href: next_path
            end
          end
          img src: asset("svgs/next_page.svg"), alt: "next_page", class: "h-[24px]"
        end
      end
    end
  end
end
