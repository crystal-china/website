class SaveCommentThread < CommentThread::SaveOperation
  permit_columns doc_id, topic_id
end
