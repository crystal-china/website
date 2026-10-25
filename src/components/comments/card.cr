class Comments::Card < BaseComponent
  needs formatter : Tartrazine::Formatter
  needs comment : Comment
  needs order_by : String
  needs show_update_success : Bool = false
  needs focused_comment_id : Int64? = nil

  # 通知定位子评论时，自动展开所属根评论的回复。
  needs reply_expanded : Bool = false

  def render : Nil
    focus_id = focused_comment_id
    options = {} of String => String

    if focus_id == comment.id
      scroll_to_and_highlight_comment_script = <<-HYPER
init
  wait a tick
  scroll to the middle of me smoothly
  add .comment-focused
  wait for animationend
  remove .comment-focused
end
HYPER

      options["script"] = scroll_to_and_highlight_comment_script
    end

    article(
      options,
      class: comment_card_classes,
      id: "comment-#{comment.id}"
    ) do
      mount(
        Comments::CardBody,
        formatter: formatter,
        comment: comment,
        order_by: order_by,
        show_update_success: show_update_success?,
        current_user: current_user
      )

      if comment.parent_id.nil?
        mount(
          Comments::Replies,
          formatter: formatter,
          root_comment: comment,
          order_by: order_by,
          focused_comment_id: reply_expanded? ? focus_id : nil,
          current_user: current_user
        )
      end
    end
  end

  private def comment_card_classes : String
    # 主体局部替换后，背景色随其撤回状态变化，不需要重新渲染外壳。
    classes = "app-panel mt-6 px-4 py-2 sm:px-7 has-[>.comment-withdrawn]:bg-gray-100"
    classes += comment.parent_id ? " bg-green-100" : " bg-white"
    classes += " sm:ml-8" if comment.parent_id
    classes += " comment-root" if comment.parent_id.nil?

    classes
  end
end
