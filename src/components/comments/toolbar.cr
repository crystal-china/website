# 顶级评论的 toolbar
class Comments::Toolbar < BaseComponent
  needs pagination : Comments::Pagination
  needs html_id : String

  def render : Nil
    div class: "mt-4 flex items-center justify-between gap-4" do
      span(
        r(".reply_count").t(count: pagination[:count]),
        id: "#{html_id}-count",
        class: "text-base font-medium text-gray-900"
      )

      mount(
        Comments::SortOrder,
        url: pagination[:url],
        target_id: html_id,
        order_by: pagination[:order_by]
      )
    end
  end
end
