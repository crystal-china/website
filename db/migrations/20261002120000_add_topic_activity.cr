class AddTopicActivity::V20261002120000 < Avram::Migrator::Migration::V1
  def migrate
    alter table_for(Topic) do
      # 当前可见回复总数，包含子评论；根评论已删除的整个分支不参与统计。
      # Comment::SaveOperation 的 callback 在新增、软删除和恢复后重新计算。
      add replies_count : Int32, default: 0

      # 最后一条可见回复的作者；没有回复时为空，不复制可能变更的用户名。
      add_belongs_to last_reply_user : User?, on_delete: :nullify

      # 新主题默认当前时间；有回复后使用最后一条可见回复的创建时间。
      # 删除全部可见回复或回填统计时，回退到主题创建时间。
      # 编辑正文不更新此值；列表按此字段排序，而不是按 updated_at 排序。
      add last_active_at : Time, default: :now
    end

    create_index table_for(Topic), [:last_active_at, :id]
    create_index table_for(Topic), [:node_id, :last_active_at, :id]
  end

  def rollback
    drop_index table_for(Topic), [:node_id, :last_active_at, :id]
    drop_index table_for(Topic), [:last_active_at, :id]

    alter table_for(Topic) do
      remove_belongs_to :last_reply_user
      remove :last_active_at
      remove :replies_count
    end
  end
end
