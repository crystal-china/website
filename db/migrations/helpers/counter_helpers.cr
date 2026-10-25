module Db::CounterHelpers
  def add_counters_for(
    *,
    source_table : String,
    target_table : String,
    target_column : String,
    target_id_column : String,
    when when_clause : String? = nil,
  ) : Nil
    add_counter_functions(
      source_table: source_table,
      target_table: target_table,
      target_column: target_column,
      target_id_column: target_id_column,
      when: when_clause
    )

    add_counter_triggers(
      source_table: source_table,
      target_table: target_table,
      target_column: target_column,
    )
  end

  # 创建 PostgreSQL trigger/function，维护源表中未软删除记录的数量：
  # - source_table：监听变化的源表。
  # - target_table / target_column：存放计数的目标表及字段。
  # - target_id_column：源表中的外键，通过它找到目标表的 id；为空时不计数。
  # - when：额外的源表行条件，省略则不额外过滤；内部会加上 NEW./OLD. 前缀。
  #
  # 例如，只统计每个评论区的根评论：
  # add_soft_delete_counters_for(
  #   source_table: "comments",
  #   target_table: "comment_threads",
  #   target_column: "root_comments_count",
  #   target_id_column: "comment_thread_id",
  #   when: "parent_id IS NULL"
  # )
  # comment_thread_id = 10 的根评论新增/恢复时，评论区 10 的计数 +1；软删除时 -1。
  # 子回复不计入，撤回不影响计数；物理删除已软删除的评论不会再次递减。
  # 这里只创建 trigger/function，不会回填已有记录的计数，需由 migration 另外处理。
  def add_soft_delete_counters_for(
    *,
    source_table : String,
    target_table : String,
    target_column : String,
    target_id_column : String,
    when when_clause : String? = nil,
  ) : Nil
    add_counter_functions(
      source_table: source_table,
      target_table: target_table,
      target_column: target_column,
      target_id_column: target_id_column,
      when: when_clause
    )

    add_soft_delete_counter_triggers(
      source_table: source_table,
      target_table: target_table,
      target_column: target_column
    )
  end

  private def add_counter_functions(
    *,
    source_table : String,
    target_table : String,
    target_column : String,
    target_id_column : String,
    when when_clause : String? = nil,
  ) : Nil
    key = "#{source_table}_#{target_table}_#{target_column}"

    execute <<-SQL
CREATE OR REPLACE FUNCTION increment_#{key}()
RETURNS TRIGGER AS $$
DECLARE
    target_id bigint;
BEGIN
    target_id := NEW.#{target_id_column};

    IF target_id IS NOT NULL#{when_clause ? " AND NEW.#{when_clause}" : ""} THEN
        UPDATE #{target_table}
        SET #{target_column} = #{target_column} + 1
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
    target_id := OLD.#{target_id_column};

    IF target_id IS NOT NULL#{when_clause ? " AND OLD.#{when_clause}" : ""} THEN
        UPDATE #{target_table}
        SET #{target_column} = #{target_column} - 1
        WHERE id = target_id;
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;
SQL
  end

  private def add_counter_triggers(*, source_table : String, target_table : String, target_column : String, when when_clause : String? = nil) : Nil
    key = "#{source_table}_#{target_table}_#{target_column}"

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

  private def add_soft_delete_counter_triggers(*, source_table : String, target_table : String, target_column : String) : Nil
    key = "#{source_table}_#{target_table}_#{target_column}"

    add_counter_triggers(
      source_table: source_table,
      target_table: target_table,
      target_column: target_column,
      when: "soft_deleted_at IS NULL"
    )

    execute <<-SQL
CREATE TRIGGER trigger_soft_delete_#{key}
AFTER UPDATE OF soft_deleted_at ON #{source_table}
FOR EACH ROW
WHEN (OLD.soft_deleted_at IS NULL AND NEW.soft_deleted_at IS NOT NULL)
EXECUTE FUNCTION decrement_#{key}();
SQL

    execute <<-SQL
CREATE TRIGGER trigger_restore_#{key}
AFTER UPDATE OF soft_deleted_at ON #{source_table}
FOR EACH ROW
WHEN (OLD.soft_deleted_at IS NOT NULL AND NEW.soft_deleted_at IS NULL)
EXECUTE FUNCTION increment_#{key}();
SQL
  end

  def remove_counters_for(*, source_table : String, target_table : String, target_column : String) : Nil
    key = "#{source_table}_#{target_table}_#{target_column}"

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

  def remove_soft_delete_counters_for(*, source_table : String, target_table : String, target_column : String) : Nil
    key = "#{source_table}_#{target_table}_#{target_column}"

    execute "DROP TRIGGER IF EXISTS trigger_soft_delete_#{key} ON #{source_table};"
    execute "DROP TRIGGER IF EXISTS trigger_restore_#{key} ON #{source_table};"

    remove_counters_for(
      source_table: source_table,
      target_table: target_table,
      target_column: target_column
    )
  end
end

class Avram::Migrator::Migration::V1
  include Db::CounterHelpers
end
