class Comments::Toolbar < BaseComponent
  needs pagination : Comments::Pagination
  needs html_id : String

  def render
    selected = "segmented-option segmented-option-active"
    unselected = "segmented-option"

    div class: "mt-4 flex items-center justify-between gap-4" do
      span "共 #{pagination[:count]} 条回复", id: "#{html_id}-count", class: "text-base font-medium text-gray-900"

      div class: "segmented-control" do
        [{"最早", "asc"}, {"最新", "desc"}].each do |title, order|
          a(
            title,
            class: pagination[:order_by] == order ? selected : unselected,
            href: "#{pagination[:url]}&order_by=#{order}",
            hx_get: "#{pagination[:url]}&order_by=#{order}",
            hx_target: "##{html_id}",
            hx_swap: "outerHTML",
            script: <<-HYPER
  on click
    set the value of the first .comment-order-state in the closest <article/> to "#{order}"
  end
HYPER
          )
        end
      end
    end
  end
end
