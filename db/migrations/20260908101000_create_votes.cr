class CreateVotes::V20260908101000 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(Vote) do
      primary_key id : Int64
      add vote_type : String
      add_belongs_to user : User, on_delete: :cascade
      add_belongs_to comment : Comment?, on_delete: :cascade
      add_belongs_to doc : Doc?, on_delete: :cascade
      add_timestamps
    end

    # 投票必须且只能属于一篇文档或一条评论。
    require_nullability_relation(:exactly_one_non_null, "votes", "doc_id", "comment_id")

    # 每个用户针对同一个目标，每种投票类型只能选择一次。
    create_index table_for(Vote), [:vote_type, :user_id, :comment_id], unique: true
    create_index table_for(Vote), [:vote_type, :user_id, :doc_id], unique: true
  end

  def rollback
    drop table_for(Vote)
  end
end
