module Db::CounterHelpers
  def add_counters_for(*, source_table : String, target_table : String, target_column : String, target_id_column : String)
    counter_function_sql(
      source_table: source_table,
      target_table: target_table,
      target_column: target_column,
      target_id_column: target_id_column
    )

    trigger_sql(
      source_table: source_table,
      target_table: target_table,
      target_column: target_column,
    )
  end

  def remove_counters_for(*, source_table : String, target_table : String, target_column : String)
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

  private def counter_function_sql(*, source_table : String, target_table : String, target_column : String, target_id_column : String)
    key = "#{source_table}_#{target_table}_#{target_column}"

    execute <<-SQL
CREATE OR REPLACE FUNCTION increment_#{key}()
RETURNS TRIGGER AS $$
DECLARE
    target_id bigint;
BEGIN
    target_id := NEW.#{target_id_column};

    IF target_id IS NOT NULL THEN
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

    IF target_id IS NOT NULL THEN
        UPDATE #{target_table}
        SET #{target_column} = #{target_column} - 1
        WHERE id = target_id;
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;
SQL
  end

  private def trigger_sql(*, source_table : String, target_table : String, target_column : String)
    key = "#{source_table}_#{target_table}_#{target_column}"

    execute <<-SQL
CREATE TRIGGER trigger_increment_#{key}
AFTER INSERT ON #{source_table}
FOR EACH ROW
EXECUTE FUNCTION increment_#{key}();
SQL

    execute <<-SQL
CREATE TRIGGER trigger_decrement_#{key}
AFTER DELETE ON #{source_table}
FOR EACH ROW
EXECUTE FUNCTION decrement_#{key}();
SQL
  end
end

class Avram::Migrator::Migration::V1
  include Db::CounterHelpers
end
