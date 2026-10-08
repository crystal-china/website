class Htmx::Search < BrowserAction
  param q : String?
  param scope : String?

  get "/htmx/search" do
    return head 400 unless scope == "docs" || scope == "topics"

    query = q.to_s.strip

    if query.bytesize < 4
      return component(
        ::Search::Results,
        matches: [] of NamedTuple(title: String, url: String, snippet: String),
        query: query,
        too_short: !query.empty?,
        current_user: current_user
      )
    end

    matches = if scope == "docs"
                search_docs(query)
              else
                search_topics(query)
              end

    component(
      ::Search::Results,
      matches: matches,
      query: query,
      current_user: current_user
    )
  end

  private def search_docs(query : String)
    DocNavigation.load
    pages_by_path = DocNavigation.pages_by_path

    # Generate snippets only for the limited result set.
    sql = <<-SQL
        WITH matches AS MATERIALIZED (
          SELECT path_index, content, pgroonga_score(tableoid, ctid) AS score
          FROM docs
          WHERE content &@~ pgroonga_query_escape($1::text)
          ORDER BY score DESC, path_index
          LIMIT 20
        )
        SELECT path_index,
               COALESCE((pgroonga_snippet_html(content, pgroonga_query_extract_keywords(pgroonga_query_escape($1::text)), 120))[1], '')
        FROM matches
        ORDER BY score DESC, path_index
      SQL

    AppDatabase.query_all(sql, query) do |rs|
      path, snippet = rs.read(String, String)

      {
        title:   pages_by_path[path]?.try(&.title) || path.split('/').last,
        url:     path,
        snippet: snippet,
      }
    end
  end

  private def search_topics(query : String)
    # 与表达式索引一致，允许关键词分别出现在标题和正文中。
    sql = <<-SQL
      WITH matches AS MATERIALIZED (
        SELECT id, title, title || ' ' || content AS search_content,
               pgroonga_score(tableoid, ctid) AS score
        FROM topics
        WHERE soft_deleted_at IS NULL
          AND (title || ' ' || content) &@~ pgroonga_query_escape($1::text)
        ORDER BY score DESC, id DESC
        LIMIT 20
      )
      SELECT id, title,
             COALESCE((pgroonga_snippet_html(search_content, pgroonga_query_extract_keywords(pgroonga_query_escape($1::text)), 120))[1], '')
      FROM matches
      ORDER BY score DESC, id DESC
      SQL

    AppDatabase.query_all(sql, query) do |rs|
      id, title, snippet = rs.read(Int64, String, String)

      {
        title:   title,
        url:     Forum::Show.with(id: id).path,
        snippet: snippet,
      }
    end
  end
end
