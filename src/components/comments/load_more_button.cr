class Comments::LoadMoreButton < BaseComponent
  needs pagination : Comments::Pagination
  needs page_number : Int32

  def render
    div class: "mt-4 flex justify-center" do
      if pagination[:page].try &.next_page
        button(
          type: "button",
          class: "action-button action-button-neutral",
          hx_get: "#{pagination[:url]}&page=#{page_number + 1}&order_by=#{pagination[:order_by]}",
          hx_target: "closest div",
          hx_swap: "outerHTML",
        ) do
          text "加载更多评论"
          mount Shared::Spinner, text: "正在读取评论..."
        end
      else
        span "没有更多评论了", class: "text-base text-gray-500"
      end
    end
  end
end
