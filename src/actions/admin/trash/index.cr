class Admin::Trash::Index < AdminAction
  include Lucky::Paginator::BackendHelpers

  param kind : String = "comments"

  get "/admin/trash" do
    return head 400 unless kind.in?("comments", "topics")

    if kind == "comments"
      pages, items = paginate(
        CommentQuery.new.only_soft_deleted.soft_deleted_at.desc_order.id.desc_order.preload_user.preload_comment_thread,
        per_page: 20
      )

      html(
        Admin::Trash::IndexPage,
        kind: kind,
        comments: items.results,
        topics: [] of Topic,
        pages: pages
      )
    else
      pages, items = paginate(TopicQuery.new.only_soft_deleted.soft_deleted_at.desc_order.id.desc_order.preload_user, per_page: 20)

      html(
        Admin::Trash::IndexPage,
        kind: kind,
        comments: [] of Comment,
        topics: items.results,
        pages: pages
      )
    end
  end
end
