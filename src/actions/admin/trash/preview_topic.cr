class Admin::Trash::PreviewTopic < AdminAction
  include Lucky::Paginator::BackendHelpers

  get "/admin/trash/topics/:id/preview" do
    topic = TopicQuery.new
      .only_soft_deleted
      .id(id)
      .preload_user
      .preload_node
      .preload_comment_thread
      .first

    query = CommentQuery.new
      .with_soft_deleted
      .comment_thread_id(topic.comment_thread.not_nil!.id)
      .id.asc_order
      .preload_user

    query.preload_parent(&.preload_user)
    pages, comments = paginate(query, per_page: 20)

    html(
      Admin::Trash::PreviewTopicPage,
      topic: topic,
      comments: comments.results,
      pages: pages
    )
  end
end
