class CreateTopics::V20260908090000 < Avram::Migrator::Migration::V1
  def migrate : Nil
    create table_for(Node) do
      primary_key id : Int64
      add name : String
      add slug : String
      add summary : String
      add color : String
      add position : Int32, default: 0
      add topics_count : Int32, default: 0
      add_timestamps
    end

    create_index table_for(Node), :name, unique: true
    create_index table_for(Node), :slug, unique: true

    create table_for(Topic) do
      primary_key id : Int64
      add_belongs_to space : Space, on_delete: :restrict
      add_belongs_to user : User, on_delete: :cascade
      add_belongs_to node : Node, on_delete: :restrict
      add title : String
      add content : String
      # 与 Markdown 原文同步保存的安全 HTML；NULL 时由页面临时渲染。
      add content_html : String?

      # 仅在标题或正文实际改变时写入，用于区分内容编辑和其他数据库更新。
      add edited_at : Time?
      add soft_deleted_at : Time?, index: true

      # 当前可见回复总数，包含子评论；根评论已删除的整个分支不参与统计。
      # record_topic_reply AFTER INSERT trigger 在新增时递增；软删除和恢复由 callback 重算。
      add replies_count : Int32, default: 0

      # 最后一条可见回复的 ID，供未读查询比较阅读位置；没有回复时为空。
      add last_reply_id : Int64?

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

    # 标题与正文合并索引，支持跨字段的多关键词查询；软删除主题不参与搜索。
    execute <<-SQL
      CREATE INDEX topics_title_content_pgroonga_index
      ON topics USING pgroonga ((title || ' ' || content))
      WHERE soft_deleted_at IS NULL
      SQL

    add_counters_for(
      source_table: "topics",
      source_foreign_key: "space_id",
      target_table: "spaces",
      target_counter_column: "topics_count",
      soft_delete_column: "soft_deleted_at"
    )

    add_counters_for(
      source_table: "topics",
      source_foreign_key: "node_id",
      target_table: "nodes",
      target_counter_column: "topics_count",
      soft_delete_column: "soft_deleted_at"
    )

    add_counters_for(
      source_table: "topics",
      source_foreign_key: "user_id",
      target_table: "users",
      target_counter_column: "topics_count",
      soft_delete_column: "soft_deleted_at"
    )
  end

  def rollback : Nil
    remove_counters_for(
      source_table: "topics",
      target_table: "users",
      target_counter_column: "topics_count"
    )

    remove_counters_for(
      source_table: "topics",
      target_table: "nodes",
      target_counter_column: "topics_count"
    )

    remove_counters_for(
      source_table: "topics",
      target_table: "spaces",
      target_counter_column: "topics_count"
    )

    drop table_for(Topic)
    drop table_for(Node)
  end
end
