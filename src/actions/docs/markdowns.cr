class Docs::Markdowns < DocAction
  get "/docs/*:requested_path" do
    return redirect(to: Docs::Markdowns.with(requested_path: "index")) if requested_path.nil?

    raise Lucky::RouteNotFoundError.new(context) if MarkdownFile.resolve(requested_path).nil?

    doc = find_or_create_doc
    record_view(doc)

    html Docs::MarkdownsPage, doc: doc
  end

  private def find_or_create_doc : Doc
    DocQuery.new.path_index(current_path).first? || SaveDoc.create!(path_index: current_path)
  rescue error : PQ::PQError
    raise error unless error.field_message(:constraint) == "docs_path_index_index"

    DocQuery.new.path_index(current_path).first
  end

  private def record_view(doc : Doc)
    remote_ip = context.request.remote_ip || "0.0.0.0"

    VIEW_COUNT_MUTEX.synchronize do
      VIEW_COUNT_CACHE.fetch("#{remote_ip}-#{current_path}") do
        AppDatabase.exec(
          "UPDATE docs SET view_count = view_count + 1 WHERE id = $1",
          doc.id
        )
        true
      end
    end
  end
end
