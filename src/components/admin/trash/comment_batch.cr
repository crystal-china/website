# 展开后返回的列表组件
@[Rosetta::Translatable::Config(prefix: "admin.trash.index_page")]
class Admin::Trash::CommentBatch < BaseComponent
  needs anchor_id : Int64
  needs comments : Array(Comment)
  needs pages : Lucky::Paginator
  needs focused_comment_id : Int64? = nil

  def render : Nil
    div id: "trash-comment-#{anchor_id}-replies-list" do
      para r(".other_batch_comments").t(count: pages.item_count), class: "mt-3 mb-1 text-xs font-medium text-gray-600"
      para r(".restore_order").t, class: "mt-0 mb-3 text-xs text-gray-500"

      div class: "divide-y divide-gray-200" do
        comments.each do |comment|
          mount(
            Admin::Trash::CommentCard,
            comment: comment,
            nested: true,
            focused_comment_id: comment.id == focused_comment_id ? comment.id : nil
          )
        end
      end

      div(
        "hx-target:inherited": "#trash-comment-#{anchor_id}-replies-list",
        "hx-swap:inherited": "outerHTML show:none",
        "hx-push-url:inherited": "false"
      ) do
        mount Shared::Pagination, pages: pages
      end
    end
  end
end
