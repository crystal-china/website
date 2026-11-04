# 展开同批评论的 Action
class Admin::Trash::BatchComments < AdminAction
  include Lucky::Paginator::BackendHelpers

  param deleted_at : String
  param comment_id : Int64?
  @focused_page : Int32?

  get "/admin/trash/comments/:id/batch" do
    anchor = CommentQuery.new.with_soft_deleted.id(id).first
    batch_deleted_at = Time.parse_rfc3339(deleted_at)
    query = CommentQuery.new
      .only_soft_deleted
      .comment_thread_id(anchor.comment_thread_id)
      .soft_deleted_at(batch_deleted_at)
      .id.not.eq(anchor.id)
      .id.desc_order
      .preload_user
      .preload_comment_thread
      .preload_parent

    if (focus_id = comment_id) && params.get?(:page).nil?
      focused_comment = query.id(focus_id).first
      preceding = query.id.gt(focused_comment.id)
      @focused_page = (preceding.select_count // App::DEFAULT_PER_PAGE + 1).to_i
    end

    pages, query = paginate(query, per_page: App::DEFAULT_PER_PAGE)

    component(
      Admin::Trash::CommentBatch,
      anchor_id: anchor.id,
      comments: query.results,
      pages: pages,
      focused_comment_id: comment_id
    )
  rescue Time::Format::Error
    head 400
  end

  def paginator_page : Int32
    @focused_page || super
  end
end
