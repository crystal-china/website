class CreateDocs::V20250309141337 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(Doc) do
      primary_key id : Int64
      add path_index : String, unique: true, index: true
      add view_count : Int32, default: 0

      # 旧版文档评论的顶级楼层计数器。新评论系统改用 CommentThread#floor_counter；
      # 这里暂时保留，只为兼容现有 Doc 模型和线上数据库结构。
      add floor_counter : Int32, default: 0
      add vote_counts : JSON::Any, default: JSON.parse({"👍" => 0, "👎" => 0, "❤️" => 0}.to_json)
      add_timestamps
    end
  end

  def rollback
    drop table_for(Doc)
  end
end
