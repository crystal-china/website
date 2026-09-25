class Comments::Toolbar < BaseComponent
  needs pagination : Comments::Pagination
  needs html_id : String

  def render
    selected = "inline-flex items-center rounded-lg border border-gray-300 bg-white px-4 py-1.5 text-sm font-semibold text-gray-950 shadow-[0_1px_2px_rgb(15_23_42/0.08)]"
    unselected = "inline-flex items-center rounded-lg border border-transparent px-4 py-1.5 text-sm font-medium text-gray-600 transition hover:border-gray-300/70 hover:bg-white/70 hover:text-gray-900"

    div class: "mt-4 flex items-center justify-between gap-4" do
      span "共 #{pagination[:count]} 条回复", id: "#{html_id}-count", class: "text-base font-medium text-gray-900"

      div class: "flex items-center gap-1 rounded-xl border border-gray-200 bg-gray-100 p-1 shadow-inner" do
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
