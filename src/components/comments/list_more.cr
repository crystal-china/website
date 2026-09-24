class Comments::ListMore < BaseComponent
  needs formatter : Tartrazine::Formatter
  needs pagination : Comments::Pagination
  needs page_number : Int32
  needs comment_id : Int64?

  def render
    pagination[:comments].results.each do |comment|
      mount(
        Comments::Card,
        formatter: formatter,
        comment: comment,
        order_by: pagination[:order_by],
        show_update_success: comment_id == comment.id,
        current_user: current_user
      )
    end

    mount(
      Comments::LoadMoreButton,
      pagination: pagination,
      page_number: page_number,
    )
  end
end
