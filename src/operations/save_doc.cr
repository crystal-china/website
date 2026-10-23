class SaveDoc < Doc::SaveOperation
  before_save do
    content.allow_blank = true
  end

  after_save create_comment_thread, if: :new_record?

  private def create_comment_thread(doc : Doc) : Nil
    SaveCommentThread.create!(doc_id: doc.id)
  end
end
