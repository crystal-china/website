class Admin::Trash::Index < AdminAction
  include Lucky::Paginator::BackendHelpers

  param kind : String = "comments"
  param q : String = ""

  get "/admin/trash" do
    return head 400 unless kind.in?("comments", "topics")

    keyword = q.strip
    pattern = "%#{SqlLike.escape(keyword)}%"

    if kind == "comments"
      comments_query = CommentQuery.new
        .only_soft_deleted
        .soft_deleted_at.desc_order
        .id.desc_order
        .preload_user
        .preload_comment_thread

      comments_query = comments_query.content.ilike(pattern) unless keyword.empty?
      pages, comments_query = paginate(comments_query, per_page: 20)
      comments = comments_query.results
      topics = [] of Topic
    else
      topics_query = TopicQuery.new
        .only_soft_deleted
        .soft_deleted_at.desc_order
        .id.desc_order
        .preload_user

      unless keyword.empty?
        topics_query = topics_query.where(
          "(topics.title ILIKE ? OR topics.content ILIKE ?)",
          pattern,
          pattern
        )
      end

      pages, topics_query = paginate(topics_query, per_page: 20)
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
      )
    end

    html(
      Admin::Trash::IndexPage,
      kind: kind,
      keyword: keyword,
      comments: comments,
      topics: topics,
      pages: pages
    )
  end
end
