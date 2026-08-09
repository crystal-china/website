class Docs::FormButtons < BaseComponent
  needs page_count : Int32 | Int64
  needs reply_path : String
  needs order_by : String
  needs hx_target : String

  def render
    div class: "mt-4 flex items-center justify-between gap-4" do
      span "共 #{page_count} 条回复", class: "text-base font-medium text-gray-900"

      div class: "flex items-center gap-3" do
        render_order_buttons(reply_path)
      end
    end
  end

  private def render_order_buttons(reply_path : String)
    selected = "inline-flex items-center rounded-full border border-sky-600 bg-white px-4 py-1.5 text-sm font-semibold text-sky-700 shadow-sm"
    unselected = "inline-flex items-center rounded-full border border-transparent bg-gray-200 px-4 py-1.5 text-sm font-medium text-gray-500 hover:border-gray-300 hover:text-gray-700"

    # 这里利用了一个狡黠的 htmx hack，点击下面的连接，生成的 url 如下：
    # /docs/replies/index?order_by=asc&order_by=desc
    # 此时有两个 order_by，第一个来自于 hx_get 中的 ? 参数, 第二个来自于 hx_include
    # 此时，总是第一个生效。

    [{"最早", "asc"}, {"最新", "desc"}].each do |title, order|
      a(
        title,
        class: order_by == order ? selected : unselected,
        href: "#{reply_path}?order_by=#{order}",
        hx_get: "#{reply_path}?order_by=#{order}",
        hx_target: hx_target,
        hx_swap: "outerHTML",
        hx_include: "next input[name='order_by']",
      )
    end

    # 为了记录上次点击的 order_by 顺序，传递 order_by 到服务器，并重新写入隐藏 input
    input type: "hidden", name: "order_by", value: order_by
  end
end
