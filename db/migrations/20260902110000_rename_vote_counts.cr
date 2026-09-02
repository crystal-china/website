class RenameVoteCounts::V20260902110000 < Avram::Migrator::Migration::V1
  def migrate
    alter table_for(Doc) do
      rename :votes, :vote_counts
    end

    alter table_for(Reply) do
      rename :votes, :vote_counts
    end
  end

  def rollback
    alter table_for(Reply) do
      rename :vote_counts, :votes
    end

    alter table_for(Doc) do
      rename :vote_counts, :votes
    end
  end
end
