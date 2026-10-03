class CreateComments::V20260908100000 < Avram::Migrator::Migration::V1
  def migrate
    create table_for(Comment) do
      primary_key id : Int64

      # 评论所属的唯一评论区。Doc 和 Topic 均通过 CommentThread 共用 comments 表。
      add_belongs_to comment_thread : CommentThread, on_delete: :cascade

      # 直接回复的评论；顶级评论为 NULL。
      add_belongs_to parent : Comment?, on_delete: :cascade

      # 所属分支的顶级评论；顶级评论为 NULL，同一分支的所有后代均指向同一个 root。
      add_belongs_to root : Comment?, on_delete: :cascade
      add_belongs_to user : User, on_delete: :cascade
      add content : String

      # 只在评论正文确实被修改时写入；投票和计数器更新不会影响它。
      add edited_at : Time?
      add soft_deleted_at : Time?, index: true

      # 当前作用域内的显示楼层：顶级评论按 CommentThread 编号，子评论按 root 分支编号。
      # assign_comment_floor BEFORE INSERT trigger 自动分配该值。
      add floor : Int32

      # 仅根评论使用，记录该分支已分配的最大子评论楼层。
      # 新增子评论时，assign_comment_floor trigger 原子自增它，并将新值写入子评论的 floor。
      add floor_counter : Int32, default: 0

      # 整个根评论分支未软删除的后代总数，由基于 root_id 的 counter triggers 维护。
      # 新增或恢复时递增，软删除或物理删除未软删除记录时递减。
      add descendants_count : Int32, default: 0

      # 当前评论未软删除的直接子评论数，由基于 parent_id 的 counter triggers 维护。
      # 新增或恢复时递增，软删除或物理删除未软删除记录时递减。
      add children_count : Int32, default: 0

      # 各 emoji 票数的反规范化汇总，由投票事务同步维护，避免渲染时逐票聚合。
      add vote_counts : JSON::Any
      add_timestamps
    end

    require_nullability_relation(:both_null_or_both_non_null, "comments", "parent_id", "root_id")

    execute <<-SQL
      CREATE UNIQUE INDEX comments_comment_thread_id_floor_index
      ON comments (comment_thread_id, floor)
      WHERE parent_id IS NULL
      SQL

    create_index table_for(Comment), [:root_id, :floor], unique: true

    add_soft_delete_counters_for(
      source_table: "comments",
      target_table: "comments",
      target_column: "children_count",
      target_id_column: "parent_id",
    )

    add_soft_delete_counters_for(
      source_table: "comments",
      target_table: "comments",
      target_column: "descendants_count",
      target_id_column: "root_id",
    )

    create_function "assign_comment_floor", <<-SQL
      BEGIN
        IF NEW.parent_id IS NULL THEN
          UPDATE comment_threads
          SET floor_counter = floor_counter + 1
          WHERE id = NEW.comment_thread_id
          RETURNING floor_counter INTO NEW.floor;
        ELSE
          UPDATE comments
          SET floor_counter = floor_counter + 1
          WHERE id = NEW.root_id
          RETURNING floor_counter INTO NEW.floor;
        END IF;

        RETURN NEW;
      END;
      SQL

    create_trigger(
      table_for(Comment),
      "assign_comment_floor_before_insert",
      "assign_comment_floor",
      on: [:insert]
    )

    create_function "record_topic_reply", <<-SQL
      BEGIN
        -- 原子递增，并直接记录本次新增回复的作者和时间；不修改主题 updated_at。
        UPDATE topics AS topic
        SET replies_count = topic.replies_count + 1,
            last_reply_user_id = NEW.user_id,
            last_active_at = NEW.created_at
        FROM comment_threads AS thread
        WHERE thread.id = NEW.comment_thread_id AND topic.id = thread.topic_id;

        RETURN NULL;
      END;
      SQL

    create_trigger(
      table_for(Comment),
      "record_topic_reply_after_insert",
      "record_topic_reply",
      callback: :after,
      on: [:insert]
    )
  end

  def rollback
    drop_trigger table_for(Comment), "record_topic_reply_after_insert"
    drop_function "record_topic_reply"

    drop_trigger table_for(Comment), "assign_comment_floor_before_insert"
    drop_function "assign_comment_floor"

    remove_soft_delete_counters_for(
      source_table: "comments",
      target_table: "comments",
      target_column: "descendants_count",
    )

    remove_soft_delete_counters_for(
      source_table: "comments",
      target_table: "comments",
      target_column: "children_count",
    )

    drop table_for(Comment)
  end
end
