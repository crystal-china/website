class SaveDoc < Doc::SaveOperation
  after_save create_comment_thread, if: :new_record?

  private def create_comment_thread(doc : Doc)
    SaveCommentThread.create!(doc_id: doc.id)
  end
end
