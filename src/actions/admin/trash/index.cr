class Admin::Trash::Index < AdminAction
  include Lucky::Paginator::BackendHelpers

  PER_PAGE = 20

  param kind : String = "comments"
  param q : String = ""
  param comment_id : Int64?
  param page : Int32 = 1

  get "/admin/trash" do
    return head 400 unless kind.in?("comments", "topics")

    keyword = q.strip
    pattern = "%#{SqlLike.escape(keyword)}%"

    if kind == "comments"
      comments_query = CommentQuery.new
        .deletion_batch_entries(keyword)
        .soft_deleted_at.desc_order
        .id.desc_order
        .preload_user
        .preload_comment_thread
        .preload_parent

      pages, comments_query = paginate(comments_query, per_page: PER_PAGE)
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

      pages, topics_query = paginate(topics_query, per_page: PER_PAGE)
      comments = [] of Comment
      topics = topics_query.results
    end

    comment_ids_with_batch_peers = find_comment_ids_with_batch_peers(comments)
    focused_comment = comment_id.try { |id| CommentQuery.new.only_soft_deleted.id(id).first? }

    if context.request.headers["HX-Request-Type"]? == "partial"
      return component(
        Admin::Trash::List,
        kind: kind,
        comments: comments,
        topics: topics,
        pages: pages,
        focused_comment: focused_comment,
        comment_ids_with_batch_peers: comment_ids_with_batch_peers
      )
    end

    html(
      Admin::Trash::IndexPage,
      kind: kind,
      keyword: keyword,
      comments: comments,
      topics: topics,
      pages: pages,
      focused_comment: focused_comment,
      comment_ids_with_batch_peers: comment_ids_with_batch_peers
    )
  end

  # 找出当前页面中，哪些入口评论有额外的同批记录
  private def find_comment_ids_with_batch_peers(comments : Array(Comment)) : Set(Int64)
    ids = Set(Int64).new

    return ids if comments.empty?

    # group_count 返回类型 Hash(Array(PGValue), Int64),
    # key 是 [评论区 ID, 删除时间]，也就是下面的 batch
    # value 是数值
    batch_counts = CommentQuery.new
      .only_soft_deleted
      .comment_thread_id.in(comments.map(&.comment_thread_id).uniq!)
      .soft_deleted_at.in(comments.map(&.soft_deleted_at.not_nil!).uniq!)
      .group(&.comment_thread_id)
      .group(&.soft_deleted_at)
      .group_count

    comments.each do |comment|
      batch = [comment.comment_thread_id, comment.soft_deleted_at.not_nil!]

      # 只将 value 超过一个的 comment id 加入 Set
      ids << comment.id if batch_counts.fetch(batch, 0_i64) > 1
    end

    ids
  end
end
