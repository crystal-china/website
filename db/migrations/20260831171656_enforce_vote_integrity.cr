class EnforceVoteIntegrity::V20260831171656 < Avram::Migrator::Migration::V1
  def migrate
    require_nullability_relation(:exactly_one_non_null, "votes", "doc_id", "reply_id")

    drop_index table_for(Vote), [:vote_type, :user_id, :reply_id], if_exists: true
    drop_index table_for(Vote), [:vote_type, :user_id, :doc_id], if_exists: true
    create_index table_for(Vote), [:vote_type, :user_id, :reply_id], unique: true
    create_index table_for(Vote), [:vote_type, :user_id, :doc_id], unique: true
  end

  def rollback
    execute "ALTER TABLE votes DROP CONSTRAINT votes_doc_id_reply_id_check"

    drop_index table_for(Vote), [:vote_type, :user_id, :reply_id], if_exists: true
    drop_index table_for(Vote), [:vote_type, :user_id, :doc_id], if_exists: true
    create_index table_for(Vote), [:vote_type, :user_id, :reply_id]
    create_index table_for(Vote), [:vote_type, :user_id, :doc_id]
  end
end
