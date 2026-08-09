class RenameRepliesCounterAndAddDocsRepliesCount::V20260808110000 < Avram::Migrator::Migration::V1
  def migrate
    alter table_for(Reply) do
      rename :replies_counter, :root_replies_count
    end

    alter table_for(Doc) do
      add replies_count : Int32, default: 0
    end
  end

  def rollback
    alter table_for(Doc) do
      remove :replies_count
    end

    alter table_for(Reply) do
      rename :root_replies_count, :replies_counter
    end
  end
end
