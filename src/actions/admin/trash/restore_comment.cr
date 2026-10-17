class Admin::Trash::RestoreComment < AdminAction
  post "/admin/trash/comments/:id/restore" do
    message = r(".comment_restored").t

    AppDatabase.transaction do
      comment = CommentQuery.new.only_soft_deleted.id(id).for_update.first
      comment.restore

      if !CommentThreadQuery.find(comment.comment_thread_id).target_visible?
        message = r(".topic_still_deleted").t
      elsif (root_id = comment.root_id) && CommentQuery.new.id(root_id).none?
        message = r(".root_still_deleted").t
      end
    end

    flash.success = message

    redirect Admin::Trash::Index
  end
end
