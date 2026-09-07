class Db::Fix::ReplyThreadData < LuckyTask::Task
  summary "Fix dirty reply thread data"

  def call
    Db::Fix::ReplyThreadDataTask.run
  end
end

module Db::Fix::ReplyThreadDataTask
  def self.run
    AppDatabase.transaction do
      AppDatabase.exec(clear_root_id_for_roots_sql)
      AppDatabase.exec(backfill_root_id_sql)
      AppDatabase.exec(reset_descendants_count_sql)
      AppDatabase.exec(recalculate_descendants_count_sql)
      AppDatabase.exec(reset_children_count_sql)
      AppDatabase.exec(recalculate_children_count_sql)
      AppDatabase.exec(recalculate_doc_reply_floors_sql)
      AppDatabase.exec(recalculate_thread_reply_floors_sql)
      AppDatabase.exec(reset_doc_floor_counters_sql)
      AppDatabase.exec(recalculate_doc_floor_counters_sql)
      AppDatabase.exec(reset_root_floor_counters_sql)
      AppDatabase.exec(recalculate_root_floor_counters_sql)
      AppDatabase.exec(remove_floor_from_preferences_sql)
    end

    puts "Done fixing reply thread data"
  end

  private def self.clear_root_id_for_roots_sql
    <<-SQL
UPDATE comments
SET root_id = NULL
WHERE parent_id IS NULL
  AND root_id IS NOT NULL;
SQL
  end

  private def self.backfill_root_id_sql
    <<-SQL
WITH RECURSIVE comment_tree AS (
  SELECT
    id,
    parent_id,
    id AS root_id
  FROM comments
  WHERE parent_id IS NULL

  UNION ALL

  SELECT
    child.id,
    child.parent_id,
    comment_tree.root_id
  FROM comments AS child
  INNER JOIN comment_tree ON child.parent_id = comment_tree.id
)
UPDATE comments
SET root_id = comment_tree.root_id
FROM comment_tree
WHERE comments.id = comment_tree.id
  AND comments.parent_id IS NOT NULL;
SQL
  end

  private def self.reset_descendants_count_sql
    <<-SQL
UPDATE comments
SET descendants_count = 0
WHERE descendants_count <> 0;
SQL
  end

  private def self.recalculate_descendants_count_sql
    <<-SQL
UPDATE comments
SET descendants_count = counts.total
FROM (
  SELECT
    root_id,
    COUNT(*)::int AS total
  FROM comments
  WHERE root_id IS NOT NULL
  GROUP BY root_id
) AS counts
WHERE comments.id = counts.root_id;
SQL
  end

  private def self.reset_children_count_sql
    <<-SQL
UPDATE comments
SET children_count = 0
WHERE children_count <> 0;
SQL
  end

  private def self.recalculate_children_count_sql
    <<-SQL
UPDATE comments
SET children_count = counts.total
FROM (
  SELECT
    parent_id,
    COUNT(*)::int AS total
  FROM comments
  WHERE parent_id IS NOT NULL
  GROUP BY parent_id
) AS counts
WHERE comments.id = counts.parent_id;
SQL
  end

  private def self.recalculate_doc_reply_floors_sql
    <<-SQL
WITH ranked AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY doc_id
      ORDER BY created_at ASC, id ASC
    )::int AS floor
  FROM comments
  WHERE parent_id IS NULL
    AND doc_id IS NOT NULL
)
UPDATE comments
SET floor = ranked.floor
FROM ranked
WHERE comments.id = ranked.id;
SQL
  end

  private def self.recalculate_thread_reply_floors_sql
    <<-SQL
WITH ranked AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY root_id
      ORDER BY created_at ASC, id ASC
    )::int AS floor
  FROM comments
  WHERE parent_id IS NOT NULL
    AND root_id IS NOT NULL
)
UPDATE comments
SET floor = ranked.floor
FROM ranked
WHERE comments.id = ranked.id;
SQL
  end

  private def self.reset_doc_floor_counters_sql
    <<-SQL
UPDATE docs
SET floor_counter = 0
WHERE floor_counter <> 0;
SQL
  end

  private def self.recalculate_doc_floor_counters_sql
    <<-SQL
UPDATE docs
SET floor_counter = floors.maximum
FROM (
  SELECT
    doc_id,
    MAX(floor)::int AS maximum
  FROM comments
  WHERE parent_id IS NULL
    AND doc_id IS NOT NULL
  GROUP BY doc_id
) AS floors
WHERE docs.id = floors.doc_id;
SQL
  end

  private def self.reset_root_floor_counters_sql
    <<-SQL
UPDATE comments
SET floor_counter = 0
WHERE floor_counter <> 0;
SQL
  end

  private def self.recalculate_root_floor_counters_sql
    <<-SQL
UPDATE comments
SET floor_counter = floors.maximum
FROM (
  SELECT
    root_id,
    MAX(floor)::int AS maximum
  FROM comments
  WHERE root_id IS NOT NULL
  GROUP BY root_id
) AS floors
WHERE comments.id = floors.root_id;
SQL
  end

  private def self.remove_floor_from_preferences_sql
    <<-SQL
UPDATE comments
SET preferences = preferences - 'floor'
WHERE preferences ? 'floor';
SQL
  end
end
