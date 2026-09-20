class Htmx::Comments::Delete < CommentAction
  delete "/htmx/comments/:id" do
    me = current_user
    return head 401 if me.nil?

    status = 200
    comments_list_id = ""
    remaining_count = 0_i64

    AppDatabase.transaction do
      comment = CommentQuery.new.id(id).for_update.first

      next status = 403 if comment.user_id != me.id
      next status = 409 if comment.children_count > 0

      DeleteComment.delete!(comment)

      if (root_id = comment.root_id)
        comments_list_id = "comment-#{root_id}-comments"
        remaining_count = CommentQuery.new.root_id(root_id).select_count
      else
        comments_list_id = "comments"
        remaining_count = CommentQuery.new
          .comment_thread_id(comment.comment_thread_id)
          .parent_id.is_nil
          .select_count
      end
    end

    return head status unless status == 200

    # 这里改为双 partial 方案。
    # 之前的一个 partial，另一个空响应方尝试删除卡片，案有个坑：
    
    # 1. 提取并处理 hx-partial。
    # 2. 发现剩余的主响应为空。
    # 3. 将其判断为“只处理 partial”，默认不再交换主 target。
    # 4. 必须 swapEmpty:true 明确要求它继续执行空的主交换，从而删除评论卡片。
    plain_text <<-HTML
      <hx-partial
        hx-target="#comment-#{id}"
        hx-swap="delete swap:1s"
      ></hx-partial>

      <hx-partial
        hx-target="##{comments_list_id}-count"
      >
        共 #{remaining_count} 条回复
      </hx-partial>
    HTML
  end
end
