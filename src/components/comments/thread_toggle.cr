class Comments::ThreadToggle < BaseComponent
  needs comment : Comment
  needs order_by : String
  needs expanded : Bool = false

  def render
    wrapper_class = comment.descendants_count > 0 ? "shrink-0" : "hidden"

    div id: "comment-#{comment.id}-thread-toggle", class: wrapper_class do
      if comment.descendants_count > 0
        input type: "hidden", class: "comment-order-state", name: "order_by", value: order_by

        button(
          type: "button",
          attrs: expanded? ? [:hidden] : [] of Symbol,
          class: button_class,
          hx_get: "/htmx/comments?root_id=#{comment.id}&page=1",
          hx_include: "previous input",
          hx_target: "#comment-#{comment.id}-comments",
          hx_swap: "outerHTML",
          flow_id: "comment-#{comment.id}-load_thread",
          script: htmx_success <<-HEREDOC
add @hidden to me
remove @hidden from the next <button/>
HEREDOC
        ) do
          text "加载子评论，共 #{comment.descendants_count} 条"
          mount Shared::Spinner, text: "正在读取评论...", width: "10px"
        end

        button(
          "折叠子评论",
          type: "button",
          attrs: expanded? ? [] of Symbol : [:hidden],
          class: button_class,
          flow_id: "comment-#{comment.id}-collapse_thread",
          script: <<-HYPER
on click
  put "" into #comment-#{comment.id}-comments
  add @hidden to me
  remove @hidden from the previous <button/>
end
HYPER
        )
      end
    end
  end

  private def button_class
    "inline-flex h-8 items-center justify-center gap-1.5 rounded-full border border-sky-200 bg-sky-50 px-3 text-sm font-medium text-sky-800 transition hover:border-sky-300 hover:bg-sky-100"
  end
end
