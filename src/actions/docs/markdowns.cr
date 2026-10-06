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
    record_view(doc)

    html Docs::MarkdownsPage,
      doc: doc,
      markdown_path: markdown_path,
      markdown_source: markdown_source
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
