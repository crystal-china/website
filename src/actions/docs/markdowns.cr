class Docs::Markdowns < DocAction
  get "/docs/*:requested_path" do
    return redirect(to: Docs::Markdowns.with(requested_path: "index")) if requested_path.nil?

    markdown_path = MarkdownFile.resolve(requested_path)
    raise Lucky::RouteNotFoundError.new(context) unless current_path == "/docs/#{requested_path}"

    if requested_path == "index"
      missing_files = [] of String
      missing_files << DocNavigation::CONFIG_PATH unless File.file?(DocNavigation::CONFIG_PATH)
      missing_files << "public/markdowns/index.md" if markdown_path.nil?

      return html Docs::SetupPage, missing_files: missing_files unless missing_files.empty?
    end

    raise Lucky::RouteNotFoundError.new(context) if markdown_path.nil?

    DocNavigation.load

    markdown_source = File.read(markdown_path)
    doc = DocContent.sync(current_path, markdown_source)
    comment_thread = CommentThreadQuery.new.doc_id(doc.id).first

    view_count = record_view(doc)

    html(
      Docs::MarkdownsPage,
      doc: doc,
      view_count: view_count,
      comment_thread: comment_thread,
      markdown_path: markdown_path,
      markdown_source: markdown_source
    )
  end

  private def record_view(doc : Doc) : Int32
    remote_ip = context.request.remote_ip || "0.0.0.0"
    view_count = doc.view_count

    VIEW_COUNT_MUTEX.synchronize do
      VIEW_COUNT_CACHE.fetch("#{remote_ip}-#{current_path}") do
        view_count = AppDatabase.query_one(
          "UPDATE docs SET view_count = view_count + 1 WHERE id = $1 RETURNING view_count",
          doc.id,
          as: Int32
        )

        true
      end
    end

    view_count
  end
end
