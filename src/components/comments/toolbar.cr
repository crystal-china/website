class Comments::Toolbar < BaseComponent
  needs pagination : Comments::Pagination
  needs html_id : String

  def render : Nil
    selected = "segmented-option segmented-option-active"
    unselected = "segmented-option"

    div class: "mt-4 flex items-center justify-between gap-4" do
      span r(".reply_count").t(count: pagination[:count]), id: "#{html_id}-count", class: "text-base font-medium text-gray-900"

      div class: "segmented-control" do
        [{r(".oldest").t, "asc"}, {r(".newest").t, "desc"}].each do |title, order|
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
