class Comments::LoadMoreButton < BaseComponent
  needs pagination : Comments::Pagination
  needs page_number : Int32

  def render : Nil
    div class: "mt-4 flex justify-center" do
      if pagination[:page].try &.next_page
        button(
          type: "button",
          class: "action-button action-button-neutral",
          hx_get: "#{pagination[:url]}&page=#{page_number + 1}&order_by=#{pagination[:order_by]}",
          hx_target: "closest div",
          hx_swap: "outerHTML",
        ) do
          text r(".load_more").t
          mount Shared::Spinner, text: r("common.loading_comments").t
        end
      else
        span r(".no_more").t, class: "text-base text-gray-500"
      end
    end
  end
end
