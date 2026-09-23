class AddContentMetadataToDocs::V20260923171757 < Avram::Migrator::Migration::V1
  def migrate
    alter table_for(Doc) do
      # Stable content identity; unlike file mtime, Git checkout does not change it.
      add content_digest : String?
      # Changes only when the Markdown content digest changes.
      add content_updated_at : Time?
    end
  end

  def rollback
    alter table_for(Doc) do
      remove :content_digest
      remove :content_updated_at
    end
  end
end
