class CreateVotes::V20250311153840 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(Vote) do
      primary_key id : Int64
      add vote_type : String
      add_belongs_to user : User, on_delete: :cascade
      add_belongs_to reply : Reply?, on_delete: :cascade
      add_belongs_to doc : Doc?, on_delete: :cascade
      add_timestamps
    end

    # A vote belongs to exactly one target, either a document or a reply.
    require_nullability_relation(:exactly_one_non_null, "votes", "doc_id", "reply_id")

    # Each user can select each vote type only once per target.
    create_index table_for(Vote), [:vote_type, :user_id, :reply_id], unique: true
    create_index table_for(Vote), [:vote_type, :user_id, :doc_id], unique: true
  end

  def rollback
    drop table_for(Vote)
  end
end
