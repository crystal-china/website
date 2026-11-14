module CommentVisibility
  # 判断评论及其所属主题或文档是否公开可访问。
  def comment_available?(comment : Comment) : Bool
    CommentQuery.new.id(comment.id).publicly_visible_comments.any?
  end
end
