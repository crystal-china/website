class Docs::FormButtons < BaseComponent
  needs pagination : {count: Int32 | Int64, replies: ReplyQuery, page: Lucky::Paginator?, url: String, order_by: String}
  needs hx_target : String

  def render
    selected = "inline-flex items-center rounded-full border border-sky-600 bg-white px-4 py-1.5 text-sm font-semibold text-sky-700 shadow-sm"
    unselected = "inline-flex items-center rounded-full border border-transparent bg-gray-200 px-4 py-1.5 text-sm font-medium text-gray-500 hover:border-gray-300 hover:text-gray-700"

    div class: "mt-4 flex items-center justify-between gap-4" do
      span "共 #{pagination[:count]} 条回复", class: "text-base font-medium text-gray-900"

      # 这里之前利用了一个狡黠的 htmx hack，点击下面的连接，生成的 url 如下：
      # /docs/replies/index?order_by=asc&order_by=desc
      # 此时有两个 order_by，第一个来自于 hx_get 中的 ? 参数, 第二个来自于 hx_include
      # 此时，总是第一个生效。·

      div class: "flex items-center gap-3" do
        [{"最早", "asc"}, {"最新", "desc"}].each do |title, order|
          a(
            title,
            class: pagination[:order_by] == order ? selected : unselected,
            href: "#{pagination[:url]}?order_by=#{order}",
            hx_get: "#{pagination[:url]}?order_by=#{order}",
            hx_target: hx_target,
            hx_swap: "outerHTML",
            script: <<-HYPER
  on click
    set the value of the first .reply-order-state in the closest <article/> to "#{order}"
  end
HYPER
          )
        end
      end
    end
  end
end
