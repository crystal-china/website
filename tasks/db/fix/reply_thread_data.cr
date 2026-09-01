class Db::Fix::ReplyThreadData < LuckyTask::Task
  summary "Fix dirty reply thread data"

  def call
    Db::Fix::ReplyThreadDataTask.run
  end
end

module Db::Fix::ReplyThreadDataTask
  def self.run
    AppDatabase.transaction do
      AppDatabase.exec(clear_root_reply_id_for_roots_sql)
      AppDatabase.exec(backfill_root_reply_id_sql)
      AppDatabase.exec(reset_root_replies_count_sql)
      AppDatabase.exec(recalculate_root_replies_count_sql)
      AppDatabase.exec(recalculate_doc_reply_floors_sql)
      AppDatabase.exec(recalculate_thread_reply_floors_sql)
      AppDatabase.exec(reset_doc_reply_floor_counters_sql)
      AppDatabase.exec(recalculate_doc_reply_floor_counters_sql)
      AppDatabase.exec(reset_root_reply_floor_counters_sql)
      AppDatabase.exec(recalculate_root_reply_floor_counters_sql)
      AppDatabase.exec(remove_floor_from_preferences_sql)
    end

    puts "Done fixing reply thread data"
  end

  private def self.clear_root_reply_id_for_roots_sql
    <<-SQL
UPDATE replies
SET root_reply_id = NULL
WHERE reply_id IS NULL
  AND root_reply_id IS NOT NULL;
SQL
  end

  private def self.backfill_root_reply_id_sql
    <<-SQL
WITH RECURSIVE reply_tree AS (
  SELECT
    id,
    reply_id,
    id AS root_id
  FROM replies
  WHERE reply_id IS NULL

  UNION ALL

  SELECT
    child.id,
    child.reply_id,
    reply_tree.root_id
  FROM replies AS child
  INNER JOIN reply_tree ON child.reply_id = reply_tree.id
)
UPDATE replies
SET root_reply_id = reply_tree.root_id
FROM reply_tree
WHERE replies.id = reply_tree.id
  AND replies.reply_id IS NOT NULL;
SQL
  end

  private def self.reset_root_replies_count_sql
    <<-SQL
UPDATE replies
SET root_replies_count = 0
WHERE root_replies_count <> 0;
SQL
  end

  private def self.recalculate_root_replies_count_sql
    <<-SQL
UPDATE replies
SET root_replies_count = counts.total
FROM (
  SELECT
    root_reply_id,
    COUNT(*)::int AS total
  FROM replies
  WHERE root_reply_id IS NOT NULL
  GROUP BY root_reply_id
) AS counts
WHERE replies.id = counts.root_reply_id;
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
  FROM replies
  WHERE reply_id IS NULL
    AND doc_id IS NOT NULL
)
UPDATE replies
SET floor = ranked.floor
FROM ranked
WHERE replies.id = ranked.id;
SQL
  end

  private def self.recalculate_thread_reply_floors_sql
    <<-SQL
WITH ranked AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY root_reply_id
      ORDER BY created_at ASC, id ASC
    )::int AS floor
  FROM replies
  WHERE reply_id IS NOT NULL
    AND root_reply_id IS NOT NULL
)
UPDATE replies
SET floor = ranked.floor
FROM ranked
WHERE replies.id = ranked.id;
SQL
  end

  private def self.reset_doc_reply_floor_counters_sql
    <<-SQL
UPDATE docs
SET reply_floor_counter = 0
WHERE reply_floor_counter <> 0;
SQL
  end

  private def self.recalculate_doc_reply_floor_counters_sql
    <<-SQL
UPDATE docs
SET reply_floor_counter = floors.maximum
FROM (
  SELECT
    doc_id,
    MAX(floor)::int AS maximum
  FROM replies
  WHERE reply_id IS NULL
    AND doc_id IS NOT NULL
  GROUP BY doc_id
) AS floors
WHERE docs.id = floors.doc_id;
SQL
  end

  private def self.reset_root_reply_floor_counters_sql
    <<-SQL
UPDATE replies
SET reply_floor_counter = 0
WHERE reply_floor_counter <> 0;
SQL
  end

  private def self.recalculate_root_reply_floor_counters_sql
    <<-SQL
UPDATE replies
SET reply_floor_counter = floors.maximum
FROM (
  SELECT
    root_reply_id,
    MAX(floor)::int AS maximum
  FROM replies
  WHERE root_reply_id IS NOT NULL
  GROUP BY root_reply_id
) AS floors
WHERE replies.id = floors.root_reply_id;
SQL
  end

  private def self.remove_floor_from_preferences_sql
    <<-SQL
UPDATE replies
SET preferences = preferences - 'floor'
WHERE preferences ? 'floor';
SQL
  end
end
