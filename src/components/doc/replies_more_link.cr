class Docs::RepliesMoreLink < BaseComponent
  needs pagination : {count: Int32 | Int64, replies: ReplyQuery, page: Lucky::Paginator?, url: String, order_by: String}
  needs page_number : Int32

  def render
    div class: "mt-4 flex justify-center" do
      if pagination[:page].try &.next_page
        a(
          class: "inline-flex items-center justify-center gap-1.5 rounded-full border border-gray-300 bg-white px-4 py-1.5 text-sm font-medium text-gray-700 hover:border-gray-400 hover:bg-gray-50",
          hx_get: "#{pagination[:url]}?page=#{page_number + 1}&order_by=#{pagination[:order_by]}",
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
