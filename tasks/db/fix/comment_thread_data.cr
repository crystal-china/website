class Db::Fix::CommentThreadData < LuckyTask::Task
  summary "Fix dirty comment thread data"

  def call
    Db::Fix::CommentThreadDataTask.run
  end
end

module Db::Fix::CommentThreadDataTask
  def self.run
    AppDatabase.transaction do
      AppDatabase.exec(clear_root_id_for_roots_sql)
      AppDatabase.exec(backfill_root_id_sql)
      AppDatabase.exec(create_doc_comment_threads_sql)
      AppDatabase.exec(create_topic_comment_threads_sql)
      AppDatabase.exec(reset_descendants_count_sql)
      AppDatabase.exec(recalculate_descendants_count_sql)
      AppDatabase.exec(reset_children_count_sql)
      AppDatabase.exec(recalculate_children_count_sql)
      AppDatabase.exec(recalculate_top_level_comment_floors_sql)
      AppDatabase.exec(recalculate_thread_comment_floors_sql)
      AppDatabase.exec(reset_root_floor_counters_sql)
      AppDatabase.exec(recalculate_root_floor_counters_sql)
      AppDatabase.exec(reset_comment_thread_floor_counters_sql)
      AppDatabase.exec(recalculate_comment_thread_floor_counters_sql)
    end

    puts "Done fixing comment thread data"
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

  private def self.create_doc_comment_threads_sql
    <<-SQL
INSERT INTO comment_threads (doc_id, floor_counter, created_at, updated_at)
SELECT id, 0, NOW(), NOW()
FROM docs
ON CONFLICT (doc_id) DO NOTHING;
SQL
  end

  private def self.create_topic_comment_threads_sql
    <<-SQL
INSERT INTO comment_threads (topic_id, floor_counter, created_at, updated_at)
SELECT id, 0, NOW(), NOW()
FROM topics
ON CONFLICT (topic_id) DO NOTHING;
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

  private def self.recalculate_top_level_comment_floors_sql
    <<-SQL
WITH ranked AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY comment_thread_id
      ORDER BY created_at ASC, id ASC
    )::int AS floor
  FROM comments
  WHERE parent_id IS NULL
    AND comment_thread_id IS NOT NULL
)
UPDATE comments
SET floor = ranked.floor
FROM ranked
WHERE comments.id = ranked.id;
SQL
  end

  private def self.recalculate_thread_comment_floors_sql
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

  private def self.reset_comment_thread_floor_counters_sql
    <<-SQL
UPDATE comment_threads
SET floor_counter = 0
WHERE floor_counter <> 0;
SQL
  end

  private def self.recalculate_comment_thread_floor_counters_sql
    <<-SQL
UPDATE comment_threads
SET floor_counter = floors.maximum
FROM (
  SELECT
    comment_thread_id,
    MAX(floor)::int AS maximum
  FROM comments
  WHERE parent_id IS NULL
    AND comment_thread_id IS NOT NULL
  GROUP BY comment_thread_id
) AS floors
WHERE comment_threads.id = floors.comment_thread_id;
SQL
  end
end
