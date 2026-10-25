module Db::CounterHelpers
  # 创建 PostgreSQL trigger/function，维护源表记录的数量：
  # - source_table：监听变化的源表。
  # - source_foreign_key：源表中的外键，通过它找到目标表的 id；为空时不计数。
  # - target_table / target_counter_column：存放计数的目标表及计数字段。
  # - soft_delete_column：省略则统计所有记录；指定字段后，NULL 时计入，非 NULL 时不计入。
  #   例如指定 read_at，就统计未读通知；标记已读时 -1，重新标为未读时 +1。
  # - when：额外的源表行条件，省略则不额外过滤；内部会加上 NEW./OLD. 前缀。
  #
  # 例如，只统计每个评论区的根评论：
  # add_counters_for(
  #   source_table: "comments",
  #   source_foreign_key: "comment_thread_id",
  #   target_table: "comment_threads",
  #   target_counter_column: "root_comments_count",
  #   soft_delete_column: "soft_deleted_at",
  #   when: "parent_id IS NULL"
  # )
  # comment_thread_id = 10 的根评论新增/恢复时，评论区 10 的计数 +1；软删除时 -1。
  # 子回复不计入，撤回不影响计数；物理删除已软删除的评论不会再次递减。
  # 这里只创建 trigger/function，不会回填已有记录的计数，需由 migration 另外处理。
  # 外键及额外 when 条件涉及的字段应保持不变；helper 不维护这些字段变更后的计数迁移。
  def add_counters_for(
    *,
    source_table : String,
    source_foreign_key : String,
    target_table : String,
    target_counter_column : String,
    soft_delete_column : String? = nil,
    when when_clause : String? = nil,
  ) : Nil
    add_counter_functions(
      source_table: source_table,
      source_foreign_key: source_foreign_key,
      target_table: target_table,
      target_counter_column: target_counter_column,
      when: when_clause
    )

    if soft_delete_column
      add_soft_delete_counter_triggers(
        source_table: source_table,
        target_table: target_table,
        target_counter_column: target_counter_column,
        soft_delete_column: soft_delete_column
      )
    else
      add_counter_triggers(
        source_table: source_table,
        target_table: target_table,
        target_counter_column: target_counter_column
      )
    end
  end

  # 回填或重建一个计数字段，参数与 add_counters_for 相同。
  # when 筛选源表记录；条件放在 JOIN ON 中，没有匹配记录的目标也会更新为 0。
  # 只更新 target_counter_column，不修改 updated_at；运行时应停止并发写入。
  def rebuild_counter_for(
    *,
    source_table : String,
    source_foreign_key : String,
    target_table : String,
    target_counter_column : String,
    soft_delete_column : String? = nil,
    when when_clause : String? = nil,
  ) : Nil
    execute <<-SQL
      UPDATE #{target_table} AS target
      SET #{target_counter_column} = counts.total
      FROM (
        SELECT records.id, COUNT(source.id) AS total
        FROM #{target_table} AS records
        LEFT JOIN #{source_table} AS source
          ON source.#{source_foreign_key} = records.id
          #{soft_delete_column ? "AND source.#{soft_delete_column} IS NULL" : ""}
          #{when_clause ? "AND source.#{when_clause}" : ""}
        GROUP BY records.id
      ) AS counts
      WHERE target.id = counts.id
      SQL
  end

  private def add_counter_functions(
    *,
    source_table : String,
    source_foreign_key : String,
    target_table : String,
    target_counter_column : String,
    when when_clause : String? = nil,
  ) : Nil
    key = "#{source_table}_#{target_table}_#{target_counter_column}"

    execute <<-SQL
CREATE OR REPLACE FUNCTION increment_#{key}()
RETURNS TRIGGER AS $$
DECLARE
    target_id bigint;
BEGIN
    target_id := NEW.#{source_foreign_key};

    IF target_id IS NOT NULL#{when_clause ? " AND NEW.#{when_clause}" : ""} THEN
        UPDATE #{target_table}
        SET #{target_counter_column} = #{target_counter_column} + 1
        WHERE id = target_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
SQL

    execute <<-SQL
CREATE OR REPLACE FUNCTION decrement_#{key}()
RETURNS TRIGGER AS $$
DECLARE
    target_id bigint;
BEGIN
    target_id := OLD.#{source_foreign_key};

    IF target_id IS NOT NULL#{when_clause ? " AND OLD.#{when_clause}" : ""} THEN
        UPDATE #{target_table}
        SET #{target_counter_column} = #{target_counter_column} - 1
        WHERE id = target_id;
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;
SQL
  end

  private def add_counter_triggers(
    *,
    source_table : String,
    target_table : String,
    target_counter_column : String,
    when when_clause : String? = nil,
  ) : Nil
    key = "#{source_table}_#{target_table}_#{target_counter_column}"

    execute <<-SQL
CREATE TRIGGER trigger_increment_#{key}
AFTER INSERT ON #{source_table}
FOR EACH ROW
#{when_clause ? "WHEN (NEW.#{when_clause})" : ""}
EXECUTE FUNCTION increment_#{key}();
SQL

    execute <<-SQL
CREATE TRIGGER trigger_decrement_#{key}
AFTER DELETE ON #{source_table}
FOR EACH ROW
#{when_clause ? "WHEN (OLD.#{when_clause})" : ""}
EXECUTE FUNCTION decrement_#{key}();
SQL
  end

  private def add_soft_delete_counter_triggers(
    *,
    source_table : String,
    target_table : String,
    target_counter_column : String,
    soft_delete_column : String,
  ) : Nil
    key = "#{source_table}_#{target_table}_#{target_counter_column}"

    add_counter_triggers(
      source_table: source_table,
      target_table: target_table,
      target_counter_column: target_counter_column,
      when: "#{soft_delete_column} IS NULL"
    )

    execute <<-SQL
CREATE TRIGGER trigger_soft_delete_#{key}
AFTER UPDATE OF #{soft_delete_column} ON #{source_table}
FOR EACH ROW
WHEN (OLD.#{soft_delete_column} IS NULL AND NEW.#{soft_delete_column} IS NOT NULL)
EXECUTE FUNCTION decrement_#{key}();
SQL

    execute <<-SQL
CREATE TRIGGER trigger_restore_#{key}
AFTER UPDATE OF #{soft_delete_column} ON #{source_table}
FOR EACH ROW
WHEN (OLD.#{soft_delete_column} IS NOT NULL AND NEW.#{soft_delete_column} IS NULL)
EXECUTE FUNCTION increment_#{key}();
SQL
  end

  def remove_counters_for(
    *,
    source_table : String,
    target_table : String,
    target_counter_column : String,
  ) : Nil
    key = "#{source_table}_#{target_table}_#{target_counter_column}"

    # 普通计数没有这两个 trigger；IF EXISTS 允许共用同一个清理入口。
    execute "DROP TRIGGER IF EXISTS trigger_soft_delete_#{key} ON #{source_table};"
    execute "DROP TRIGGER IF EXISTS trigger_restore_#{key} ON #{source_table};"

    execute <<-SQL
DROP TRIGGER IF EXISTS trigger_increment_#{key} ON #{source_table};
SQL

    execute <<-SQL
DROP TRIGGER IF EXISTS trigger_decrement_#{key} ON #{source_table};
SQL

    execute <<-SQL
DROP FUNCTION IF EXISTS increment_#{key}();
SQL

    execute <<-SQL
DROP FUNCTION IF EXISTS decrement_#{key}();
SQL
  end
end

class Avram::Migrator::Migration::V1
  include Db::CounterHelpers
end
