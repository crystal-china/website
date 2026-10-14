class AddContentHtmlToTopicsAndComments::V20261014120000 < Avram::Migrator::Migration::V1
  def migrate
    alter table_for(Topic) do
      # Sanitized Markdown body, generated together with content on each body edit.
      # NULL means a legacy record awaiting db.rebuild.content_html; empty HTML is valid.
      add content_html : String?
    end

    alter table_for(Comment) do
      # Store only the body; authors, votes and action buttons remain dynamic.
      add content_html : String?
    end
  end

  def rollback
    alter table_for(Comment) do
      remove :content_html
    end

    alter table_for(Topic) do
      remove :content_html
    end
  end
end
