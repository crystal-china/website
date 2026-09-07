class Htmx::Comments::New < DocAction
  param user_id : Int64
  param order_by : String?
  param doc_path : String?
  param id : Int64?

  get "/htmx/comments/new" do
    me = current_user
    return head 401 if me.nil?
    return head 403 if user_id != me.id
    return head 400 if doc_path.nil? && id.nil?

    comment : ::Comment? = nil
    target_comment_id = nil

    # 根据 doc_path 是否存在，判断这是针对 doc 的回复还是针对评论的回复
    if doc_path.nil?
      # 评论的回复
      html_id = "comment"
      comment = CommentQuery.find(id.not_nil!)
      # target_comment_id 用于确定提交成功后替换哪个线程：顶级评论用自身 ID，子评论用所属根 ID。
      target_comment_id = comment.root_id || comment.id
    else
      # doc 的回复
      html_id = "tab"
    end

    component(
      ::Comments::Form,
      current_user: me,
      html_id: html_id,
      order_by: order_by,
      doc_path: doc_path,
      comment_id: comment.try &.id,
      target_comment_id: target_comment_id
    )
  end
end
