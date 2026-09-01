class Docs::Markdowns < DocAction
  get "/docs/*:requested_path" do
    return redirect(to: Docs::Markdowns.with(requested_path: "index")) if requested_path.nil?

    raise Lucky::RouteNotFoundError.new(context) if MarkdownFile.resolve(requested_path).nil?

    remote_ip = context.request.remote_ip || "0.0.0.0"
    VIEW_COUNT_CACHE.fetch("#{remote_ip}-#{current_path}") { true }

    html Docs::MarkdownsPage
  end
end
