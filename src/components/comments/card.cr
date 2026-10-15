class Comments::Card < BaseComponent
  needs formatter : Tartrazine::Formatter
  needs comment : Comment
  needs order_by : String
  needs show_update_success : Bool = false
  needs focused_comment : Comment? = nil

  def render : Nil
    focus = focused_comment

    # **当前卡片是不是目标评论所属的根评论？**如果是，就自动展开它，才能找到目标子评论。
    expand_thread = focus.try(&.root_id) == comment.id
    options = {} of String => String

    if focus.try(&.id) == comment.id
      options["script"] = <<-HYPER
init
  wait a tick
  scroll to the middle of me smoothly
  add .comment-focused
  wait for animationend
  remove .comment-focused
end
HYPER
    end

    article options, class: comment_card_classes, id: "comment-#{comment.id}" do
      mount(
        Comments::CardContent,
        formatter: formatter,
        comment: comment,
        show_update_success: show_update_success?,
        current_user: current_user
      )

      me = current_user
      voted_types = me ? comment.votes.map(&.vote_type) : [] of String

      footer id: "comment-#{comment.id}-footer", class: "mt-2 flex flex-wrap items-end justify-between gap-x-4 gap-y-3" do
        div class: "flex min-w-0 flex-wrap items-center gap-2 text-sm" do
          mount(
            Shared::VoteButton,
            vote_counts: Hash(String, Int32).from_json(comment.vote_counts.to_json),
            comment_id: comment.id,
            current_user: me,
            voted_types: voted_types
          )
        end

        mount Comments::CardAction,
          comment: comment,
          order_by: order_by,
          thread_expanded: expand_thread,
          current_user: me
      end

      if expand_thread && focus
        div(
          id: "comment-#{comment.id}-comments",
          hx_get: Htmx::Comments::Index.with(root_id: comment.id, comment_id: focus.id, order_by: order_by).path,
          hx_trigger: "load",
          hx_swap: "outerHTML"
        ) do
          mount Shared::Spinner, text: "正在定位评论..."
        end
      else
        div id: "comment-#{comment.id}-comments" do
        end
      end
    end
  end

  private def comment_card_classes : String
    classes = "app-panel mt-6 px-4 py-2 sm:px-7"
    classes += comment.parent_id ? " bg-green-100 sm:ml-8" : " bg-white"
    classes
  end
end
