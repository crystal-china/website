module Db::ConstraintHelpers
  # :exactly_one_non_null 要求两个字段必须且只能有一个非空。

  # 允许如下情形
  #
  # left_column | right_column
  # ------------|---------------
  # 有值         | NULL
  # NULL         | 有值

  # 不允许如下情形
  #
  # left_column | right_column
  # ------------|---------------
  # NULL         | NULL
  # 有值         | 有值

  # 例如 doc_id 和 reply_id：评论只能回复文档或另一条评论，不能同时回复两者，也不能两者都不回复。

  # :both_null_or_both_non_null 要求两个字段同时为空或同时非空。

  # 允许如下情形
  #
  # left_column | right_column
  # ------------|---------------
  # NULL         | NULL
  # 有值         | 有值

  # 不允许如下情形
  #
  # left_column | right_column
  # ------------|---------------
  # 有值         | NULL
  # NULL         | 有值

  # 例如 reply_id 和 root_reply_id：顶级评论两者都为空，子评论则必须同时记录父评论和根评论。

  # :at_least_one_non_null 要求至少一个字段非空，也允许两者都有值。
  # 例如通知：主题通知只有 topic_id，文档评论只有 comment_id，主题评论两者都有。
  def require_nullability_relation(relation : Symbol, table_name : String, left_column : String, right_column : String) : Nil
    operator = case relation
               when :exactly_one_non_null
                 "<>"
               when :both_null_or_both_non_null
                 "="
               when :at_least_one_non_null
                 "OR"
               else
                 raise ArgumentError.new("Unsupported nullability relation: #{relation}")
               end
    null_check = relation == :at_least_one_non_null ? "IS NOT NULL" : "IS NULL"

    execute <<-SQL
      ALTER TABLE #{table_name}
      ADD CONSTRAINT "#{table_name}_#{left_column}_#{right_column}_check"
      CHECK ((#{left_column} #{null_check}) #{operator} (#{right_column} #{null_check}))
      SQL
  end

  def drop_nullability_relation(relation : Symbol, table_name : String, left_column : String, right_column : String) : Nil
    execute <<-SQL
      ALTER TABLE #{table_name}
      DROP CONSTRAINT IF EXISTS "#{table_name}_#{left_column}_#{right_column}_check"
      SQL
  end

  # 两列非空时不能相等：例如 (3, 4) 允许，(3, 3) 拒绝。
  # 不限制 NULL；要求非空时，仍需在字段上定义 NOT NULL。
  def require_different_values(
    table_name : String,
    left_column : String,
    right_column : String,
  ) : Nil
    execute <<-SQL
      ALTER TABLE #{table_name}
      ADD CONSTRAINT "#{table_name}_#{left_column}_#{right_column}_different_check"
      CHECK ("#{left_column}" <> "#{right_column}")
      SQL
  end

  def drop_different_values(
    table_name : String,
    left_column : String,
    right_column : String,
  ) : Nil
    execute <<-SQL
      ALTER TABLE #{table_name}
      DROP CONSTRAINT IF EXISTS "#{table_name}_#{left_column}_#{right_column}_different_check"
      SQL
  end
end

class Avram::Migrator::Migration::V1
  include Db::ConstraintHelpers
end
