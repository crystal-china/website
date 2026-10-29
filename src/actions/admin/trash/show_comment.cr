# 父评论链接, 主要是寻找 page
class Admin::Trash::ShowComment < AdminAction
  get "/admin/trash/comments/:id" do
    comment = CommentQuery.new.with_soft_deleted.id(id).first

    return redirect Comments::Show.with(id: comment.id) unless comment.soft_deleted?

    anchor = CommentQuery.new
      .only_soft_deleted
      .comment_thread_id(comment.comment_thread_id)
      .soft_deleted_at(comment.soft_deleted_at.not_nil!)
      .id.desc_order
      .first

    # 默认 to_s 不保留小数秒，默认 pg 就保存小数后六位，适配器输出 => "2026-10-27 10:00:00.123456 +0000"
    # 另一个标准写法：comment.soft_deleted_at.not_nil!.to_rfc3339(fraction_digits: 6)
    deleted_at = Time.adapter.to_db(comment.soft_deleted_at.not_nil!)

    preceding = CommentQuery.new.deletion_batch_entries.where(
      "(comments.soft_deleted_at > ? OR (comments.soft_deleted_at = ? AND comments.id > ?))",
      deleted_at,
      deleted_at,
      anchor.id
    )
    page = (preceding.select_count // Admin::Trash::Index::PER_PAGE + 1).to_i

    # 不沿用关键词或批次筛选，确保关联评论一定能在目标分页中找到。
    redirect Admin::Trash::Index.with(page: page, comment_id: comment.id)
  end
end
