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
  def require_nullability_relation(relation : Symbol, table_name : String, left_column : String, right_column : String)
    operator = case relation
               when :exactly_one_non_null
                 "<>"
               when :both_null_or_both_non_null
                 "="
               else
                 raise ArgumentError.new("Unsupported nullability relation: #{relation}")
               end

    execute <<-SQL
      ALTER TABLE #{table_name}
      ADD CONSTRAINT "#{table_name}_#{left_column}_#{right_column}_check"
      CHECK ((#{left_column} IS NULL) #{operator} (#{right_column} IS NULL))
      SQL
  end
end

class Avram::Migrator::Migration::V1
  include Db::ConstraintHelpers
end
