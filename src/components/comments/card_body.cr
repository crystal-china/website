class Comments::CardBody < BaseComponent
  needs formatter : Tartrazine::Formatter
  needs comment : Comment
  needs order_by : String
  needs show_update_success : Bool = false
  needs reply_expanded : Bool = false
  # 展开按钮暂时仍在主体内；撤回／恢复时只保留它，不触碰外面的回复列表。
  needs preserve_thread_toggle : Bool = false

  def render : Nil
    div(
      id: "comment-#{comment.id}-body",
      class: comment.withdrawn? ? "comment-withdrawn" : "comment-body"
    ) do
      if comment.withdrawn?
        render_withdrawn
      else
        render_content
      end
    end
  end

  private def render_withdrawn : Nil
    div class: "flex flex-wrap items-center justify-between gap-3" do
      para r("common.comment_withdrawn").t, class: "m-0 text-sm text-gray-500"

      mount(
        Comments::CardControls,
        comment: comment,
        order_by: order_by,
        reply_expanded: reply_expanded?,
        preserve_thread_toggle: preserve_thread_toggle?,
        current_user: current_user
      )
    end
  end

  private def render_content : Nil
    mount(
      Comments::CardContent,
      formatter: formatter,
      comment: comment,
      show_update_success: show_update_success?,
      current_user: current_user
    )

    me = current_user
    voted_types = me ? comment.votes.map(&.vote_type) : [] of String

    footer(
      id: "comment-#{comment.id}-footer",
      class: "mt-2 flex flex-wrap items-end justify-between gap-x-4 gap-y-3"
    ) do
      div class: "flex min-w-0 flex-wrap items-center gap-x-1 gap-y-2 text-sm" do
        mount(
          Shared::VoteButton,
          vote_counts: Hash(String, Int32).from_json(comment.vote_counts.to_json),
          comment_id: comment.id,
          current_user: me,
          voted_types: voted_types
        )
      end

      mount(
        Comments::CardControls,
        comment: comment,
        order_by: order_by,
        reply_expanded: reply_expanded?,
        preserve_thread_toggle: preserve_thread_toggle?,
        current_user: me
      )
    end
  end
end
