class Admin::Trash::Index < AdminAction
  include Lucky::Paginator::BackendHelpers

  param kind : String = "comments"

  get "/admin/trash" do
    return head 400 unless kind.in?("comments", "topics")

    if kind == "comments"
      pages, comments_query = paginate(
        CommentQuery.new.only_soft_deleted.soft_deleted_at.desc_order.id.desc_order.preload_user.preload_comment_thread,
        per_page: 20
      )

      comments = comments_query.results
      topics = [] of Topic
    else
      pages, topics_query = paginate(
        TopicQuery.new.only_soft_deleted.soft_deleted_at.desc_order.id.desc_order.preload_user,
        per_page: 20
      )
      comments = [] of Comment
      topics = topics_query.results
    end

    if context.request.headers["HX-Request-Type"]? == "partial"
      return component(
        Admin::Trash::List,
        kind: kind,
        comments: comments,
        topics: topics,
        pages: pages,
        current_user: current_user
      )
    end

    html(
      Admin::Trash::IndexPage,
      kind: kind,
      comments: comments,
      topics: topics,
      pages: pages
    )
  end
end
