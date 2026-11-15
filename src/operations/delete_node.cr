class DeleteNode < Node::DeleteOperation
  needs destination_node : Node? = nil

  # 将全部主题迁到指定节点后删除原节点；没有指定目标时，只允许删除空节点。
  def delete : Bool
    deleted = false

    transaction_committed = AppDatabase.transaction do
      deleted = super

      AppDatabase.rollback unless deleted
    end

    transaction_committed && deleted
  end

  before_delete do
    if (destination = destination_node)
      if destination.id == record.id
        add_error :base, r("validations.node_destination_invalid").t
      else
        move_topics_to(destination)
      end
    end

    # 包括软删除主题；迁移后原节点必须为空，才能通过外键限制并删除。
    if TopicQuery.new.with_soft_deleted.node_id(record.id).any?
      add_error :base, r("validations.node_has_topics").t
    end
  end

  private def move_topics_to(destination : Node) : Nil
    # 一次迁移全部主题，只把其中未软删除的主题加入目标计数；原节点随后删除。
    # 不经过普通编辑 callback，保留正文、删除状态和时间，也不逐条发送移动通知。
    AppDatabase.exec(
      <<-SQL,
      WITH moved AS (
        UPDATE topics
        SET node_id = $2
        WHERE node_id = $1
        RETURNING soft_deleted_at
      )
      UPDATE nodes
      SET topics_count = topics_count + (
        SELECT COUNT(*) FROM moved WHERE soft_deleted_at IS NULL
      )
      WHERE id = $2
      SQL
      record.id,
      destination.id
    )
  end
end
