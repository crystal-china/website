require "../spec_helper"

describe Db::ConstraintHelpers do
  it "checks all four null combinations for each supported relation" do
    migration = CreateComments::V20260908100000.new
    expectations = {
      :exactly_one_non_null       => [false, true, true, false],
      :both_null_or_both_non_null => [true, false, false, true],
      :at_least_one_non_null      => [false, true, true, true],
    }

    expectations.each do |relation, expected|
      migration.reset_prepared_statements
      migration.require_nullability_relation(relation, "notifications", "topic_id", "comment_id")
      statement = migration.prepared_statements.first
      condition = statement.match!(/CHECK \((.+)\)/)[1]
      sql = <<-SQL
        SELECT #{condition}
        FROM (VALUES
          (NULL::bigint, NULL::bigint),
          (1, NULL),
          (NULL, 2),
          (1, 2)
        ) AS targets(topic_id, comment_id)
        SQL
      actual = AppDatabase.query_all(sql, as: Bool)

      actual.should eq(expected)
    end
  end
end
