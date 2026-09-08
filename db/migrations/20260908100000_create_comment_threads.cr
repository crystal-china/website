class CreateCommentThreads::V20260908100000 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(CommentThread) do
      primary_key id : Int64
      add_belongs_to doc : Doc?, on_delete: :cascade, unique: true
      add_belongs_to topic : Topic?, on_delete: :cascade, unique: true
      add floor_counter : Int32, default: 0
      add_timestamps
    end

    require_nullability_relation(:exactly_one_non_null, "comment_threads", "doc_id", "topic_id")

    alter table_for(Comment) do
      add_belongs_to comment_thread : CommentThread?, on_delete: :cascade
    end
  end

  def rollback
    alter table_for(Comment) do
      remove_belongs_to :comment_thread
    end

    drop table_for(CommentThread)
  end
end
