# 子评论的标题栏
class Comments::RepliesToolbar < BaseComponent
  needs comment : Comment
  needs order_by : String
  needs expanded : Bool = false

  def render : Nil
    # 如果没有子评论，整个标题栏都隐藏
    wrapper_class = comment.descendants_count > 0 ? "comment-replies-toggle comment-replies-toolbar" : "hidden"
    collapse_replies_and_hide_sort_controls_script = <<-HYPER
on click
  put "" into #comment-#{comment.id}-replies-list
  add @hidden to me
  remove @hidden from the previous <button/>
  add @hidden to #comment-#{comment.id}-replies-sort
end
HYPER

    div id: "comment-#{comment.id}-replies-toggle", class: wrapper_class do
      if comment.descendants_count > 0
        input(
          type: "hidden",
          name: "order_by",
          value: order_by
        )

        # + 按钮，以及数量，展开的时候隐藏
        button(
          type: "button",
          attrs: expanded? ? [:hidden] : [] of Symbol,
          class: "comment-replies-expand",
          hx_get: "/htmx/comments?root_id=#{comment.id}&page=1",
          hx_include: "previous input",
          hx_target: "#comment-#{comment.id}-replies",
          hx_swap: "outerHTML",
          flow_id: "comment-#{comment.id}-load_replies",
        ) do
          span class: "comment-replies-icon"
          span r("comments.toolbar.reply_count").t(count: comment.descendants_count)

          mount(
            Shared::Spinner,
            text: r("common.loading_comments").t,
            width: "10px"
          )
        end

        # - 按钮，以及数量，展开的时候显示。
        button(
          type: "button",
          attrs: expanded? ? [] of Symbol : [:hidden],
          class: "comment-replies-collapse",
          flow_id: "comment-#{comment.id}-collapse_replies",
          script: collapse_replies_and_hide_sort_controls_script
        ) do
          span class: "comment-replies-icon"
          span r("comments.toolbar.reply_count").t(count: comment.descendants_count)
        end

        # 排序按钮，只在展开的时候显示。
        if expanded?
          div id: "comment-#{comment.id}-replies-sort", class: "comment-replies-sort" do
            mount(
              Comments::SortOrder,
              url: Htmx::Comments::Index.with(root_id: comment.id).path,
              target_id: "comment-#{comment.id}-replies",
              order_by: order_by
            )
          end
        end
      end
    end
  end
end
