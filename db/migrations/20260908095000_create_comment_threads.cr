class CreateCommentThreads::V20260908095000 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(CommentThread) do
      primary_key id : Int64
      add_belongs_to doc : Doc?, on_delete: :cascade, unique: true
      add_belongs_to topic : Topic?, on_delete: :cascade, unique: true

      # 当前评论区已分配的最大顶级楼层。
      # 新增顶级评论时，assign_comment_floor trigger 原子自增它，并将新值写入 comments.floor。
      add floor_counter : Int32, default: 0
      add_timestamps
    end

    require_nullability_relation(:exactly_one_non_null, "comment_threads", "doc_id", "topic_id")
  end

  def rollback
    drop table_for(CommentThread)
  end
end
