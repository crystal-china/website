class Comments::Card < BaseComponent
  needs formatter : Tartrazine::Formatter
  needs comment : Comment
  needs order_by : String
  needs show_update_success : Bool = false

  def render
    article class: comment_card_classes, id: "comment-#{comment.id}" do
      mount(
        Comments::CardContent,
        formatter: formatter,
        comment: comment,
        show_update_success: show_update_success?,
        current_user: current_user
      )

      mount Comments::CardFooter,
        comment: comment,
        order_by: order_by,
        current_user: current_user

      div id: "comment-#{comment.id}-comments" do
      end
    end
  end

  private def comment_card_classes
    classes = "mt-6 rounded-2xl border border-gray-300 px-4 py-2 shadow-sm sm:px-7"
    classes += comment.parent_id ? " bg-green-100 sm:ml-8" : " bg-white"
    classes
  end
end
