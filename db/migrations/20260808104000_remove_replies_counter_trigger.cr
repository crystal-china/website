class RemoveRepliesCounterTrigger::V20260808104000 < Avram::Migrator::Migration::V1
  def migrate
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

  def rollback
  end
end
