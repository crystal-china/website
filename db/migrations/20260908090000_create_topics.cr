class CreateTopics::V20260908090000 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(Node) do
      primary_key id : Int64
      add name : String
      add slug : String
      add summary : String
      add color : String
      add position : Int32, default: 0
      add_timestamps
    end

    create_index table_for(Node), :name, unique: true
    create_index table_for(Node), :slug, unique: true

    execute <<-SQL
      INSERT INTO nodes (name, slug, summary, color, position)
      VALUES ('综合讨论', 'general', 'Crystal 语言及其生态相关的综合讨论。', '#16a34a', 100)
      SQL

    create table_for(Topic) do
      primary_key id : Int64
      add_belongs_to user : User, on_delete: :cascade
      add_belongs_to node : Node, on_delete: :restrict
      add title : String
      add content : String

      # 仅在标题或正文实际改变时写入，用于区分内容编辑和其他数据库更新。
      add edited_at : Time?
      add soft_deleted_at : Time?, index: true

      # 当前可见回复总数，包含子评论；根评论已删除的整个分支不参与统计。
      # record_topic_reply AFTER INSERT trigger 在新增时递增；软删除和恢复由 callback 重算。
      add replies_count : Int32, default: 0

      # 最后一条可见回复的作者；没有可见回复时为空，不复制可能变更的用户名。
      add_belongs_to last_reply_user : User?, on_delete: :nullify

      # 新主题默认当前时间；有回复后使用最后一条可见回复的创建时间。
      # 删除、恢复回复及回填时重新计算，没有可见回复时回到主题创建时间。
      # 编辑正文不更新此值。
      # 列表按此字段排序，而不是按 updated_at 排序。
      add last_active_at : Time, default: :now
      add_timestamps
    end

    create_index table_for(Topic), [:last_active_at, :id]
    create_index table_for(Topic), [:node_id, :last_active_at, :id]
  end

  def rollback
    drop table_for(Topic)
    drop table_for(Node)
  end
end
