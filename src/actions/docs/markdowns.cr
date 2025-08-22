class Docs::Markdowns < DocAction
  get "/docs/*:markdown_path" do
    if PageHelpers::PAGINATION_RELATION_MAPPING[current_path]?
      remote_ip = context.request.remote_ip || "0.0.0.0"

      VIEW_COUNT_CACHE.fetch("#{remote_ip}-#{current_path}") { true }

      html Docs::MarkdownsPage
    else
      head 404
    end
  end
end
