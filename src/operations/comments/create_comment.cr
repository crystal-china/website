class CreateComment < Comment::SaveOperation
  include CommentCreation

  permit_columns comment_thread_id, content

  before_save do
    prepare_new_comment if !id.value # 新建的时候

    validate_required user_id, content, comment_thread_id
  end

  after_save notify_comment_created, if: :new_record?
end
