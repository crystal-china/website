class CreateCounterTriggerForRepliesCounter::V20250718033828 < Avram::Migrator::Migration::V1
  def migrate
    execute <<-'HEREDOC'
-- 触发器函数：在插入新的 reply 时 +1
CREATE OR REPLACE FUNCTION increment_replies_counter()
RETURNS TRIGGER AS $$
BEGIN
    -- 更新 replies 表中的 replies_counter 字段
    UPDATE replies
    SET replies_counter = replies_counter + 1
    WHERE id = NEW.reply_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
HEREDOC

    execute <<-'HEREDOC'
-- 触发器函数：在删除 reply 时 -1
CREATE OR REPLACE FUNCTION decrement_replies_counter()
RETURNS TRIGGER AS $$
BEGIN
    -- 更新 replies 表中的 replies_counter 字段
    UPDATE replies
    SET replies_counter = replies_counter - 1
    WHERE id = OLD.reply_id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;
HEREDOC

    execute <<-'HEREDOC'
-- 在 replies 表上创建插入触发器
CREATE TRIGGER trigger_increment_replies_counter
AFTER INSERT ON replies
FOR EACH ROW
EXECUTE FUNCTION increment_replies_counter();
HEREDOC

    execute <<-'HEREDOC'
-- 在 replies 表上创建删除触发器
CREATE TRIGGER trigger_decrement_replies_counter
AFTER DELETE ON replies
FOR EACH ROW
EXECUTE FUNCTION decrement_replies_counter();
HEREDOC
  end

  def rollback
    execute <<-'HEREDOC'
DROP TRIGGER IF EXISTS trigger_increment_replies_counter ON replies;
HEREDOC

    execute <<-'HEREDOC'
DROP TRIGGER IF EXISTS trigger_decrement_replies_counter ON replies;
HEREDOC

    execute <<-'HEREDOC'
DROP FUNCTION IF EXISTS increment_replies_counter();
HEREDOC

    execute <<-'HEREDOC'
DROP FUNCTION IF EXISTS decrement_replies_counter();
HEREDOC
  end
end
