class AddReplyFloorIndexes::V20260830120500 < Avram::Migrator::Migration::V1
  def migrate
    create_index table_for(Reply), [:doc_id, :floor], unique: true
    create_index table_for(Reply), [:root_reply_id, :floor], unique: true
  end

  def rollback
    drop_index table_for(Reply), [:root_reply_id, :floor]
    drop_index table_for(Reply), [:doc_id, :floor]
  end
end
