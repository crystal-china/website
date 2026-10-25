class Comments::RepliesToggle < BaseComponent
  needs comment : Comment
  needs order_by : String
  needs expanded : Bool = false

  def render : Nil
    wrapper_class = comment.descendants_count > 0 ? "comment-replies-toggle" : "hidden"
    show_collapse_button_after_loading_replies = htmx_success <<-HEREDOC
add @hidden to me
remove @hidden from the next <button/>
HEREDOC
    clear_replies_and_show_expand_button = <<-HYPER
on click
  put "" into #comment-#{comment.id}-replies-list
  add @hidden to me
  remove @hidden from the previous <button/>
end
HYPER

    div id: "comment-#{comment.id}-replies-toggle", class: wrapper_class do
      if comment.descendants_count > 0
        input(
          type: "hidden",
          class: "comment-order-state",
          name: "order_by",
          value: order_by
        )

        button(
          type: "button",
          attrs: expanded? ? [:hidden] : [] of Symbol,
          class: "comment-replies-expand",
          hx_get: "/htmx/comments?root_id=#{comment.id}&page=1",
          hx_include: "previous input",
          hx_target: "#comment-#{comment.id}-replies-list",
          hx_swap: "outerHTML",
          flow_id: "comment-#{comment.id}-load_replies",
          script: show_collapse_button_after_loading_replies
        ) do
          span class: "comment-replies-icon"
          span r(".expand").t(count: comment.descendants_count)

          mount(
            Shared::Spinner,
            text: r("common.loading_comments").t,
            width: "10px"
          )
        end

        button(
          type: "button",
          attrs: expanded? ? [] of Symbol : [:hidden],
          class: "comment-replies-collapse",
          flow_id: "comment-#{comment.id}-collapse_replies",
          script: clear_replies_and_show_expand_button
        ) do
          span class: "comment-replies-icon"
          span r(".collapse").t
        end
      end
    end
  end
end
