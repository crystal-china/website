class Docs::Markdowns < DocAction
  get "/docs/*:markdown_path" do
    return redirect(to: Docs::Markdowns.with(markdown_path: "index")) if current_path == "/docs"

    remote_ip = context.request.remote_ip || "0.0.0.0"
    VIEW_COUNT_CACHE.fetch("#{remote_ip}-#{current_path}") { true }

    html Docs::MarkdownsPage
  end
end
