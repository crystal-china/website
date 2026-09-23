require "../../utils/doc_navigation"

module PageHelpers
  MARKDOWN_OPTIONS      = Markd::Options.new(gfm: true, toc: true)
  USER_MARKDOWN_OPTIONS = Markd::Options.new(gfm: true, toc: false)
  INFO_FENCE_RE         = /(?m)^```info[ \t]*\n([\s\S]*?)^```[ \t]*$/

  USER_HTML_SANITIZER = UserHtmlSanitizer.new

  def markdown(text) : String
    render_markdown_with_callouts(text)
  end

  # User-authored Markdown may contain raw HTML, so sanitize the rendered HTML
  # before inserting it into the page. Trusted documentation uses #markdown.
  def user_markdown(text) : String
    USER_HTML_SANITIZER.process(render_markdown_with_callouts(text, USER_MARKDOWN_OPTIONS))
  end

  def current_path
    context.request.path
  end

  def canonical_url
    "#{Lucky::RouteHelper.settings.base_uri}#{current_path}"
  end

  private def render_markdown_with_callouts(text : String, options = MARKDOWN_OPTIONS) : String
    render_plain_markdown(
      text.gsub(INFO_FENCE_RE) do
        render_markdown_callout($1, options)
      end,
      options
    )
  end

  private def render_plain_markdown(text : String, options = MARKDOWN_OPTIONS) : String
    Markd.to_html(
      text,
      formatter: formatter,
      options: options
    )
  end

  private def render_markdown_callout(content : String, options) : String
    <<-HTML
<div class="box info">
  <strong class="titlebar block">💡 小提示</strong>
  #{render_plain_markdown(content, options)}
</div>
HTML
  end

  private def show_comments_when_revealed(comment_thread_id : Int64)
    trigger = context.request.headers["Referer"]? ? "revealed" : "load"

    div role: "feed", id: "comments", hx_get: "/htmx/comments?comment_thread_id=#{comment_thread_id}", hx_trigger: trigger, hx_swap: "outerHTML" do
      mount Shared::Spinner, text: "正在读取评论..."
    end
  end

  private def page_container_classes
    "#{page_frame_classes} #{page_gutter_classes}"
  end

  private def page_frame_classes
    "mx-auto w-full max-w-7xl"
  end

  private def page_gutter_classes
    "px-4 sm:px-6 lg:px-8"
  end

  private def htmx_success(script)
    <<-HEREDOC
on htmx:after:request(ctx)[ctx.response.raw.ok]
#{script}
end
HEREDOC
  end

  # def asset_host
  #   Lucky::Server.settings.asset_host
  # end

  # def fingerprinted_filename(file_path : String)
  #   return file_path unless LuckyEnv.production?

  #   path = Path[file_path]
  #   basename = path.stem
  #   digest = Digest::MD5.hexdigest(File.read(path))[0..7]

  #   if basename.ends_with? digest
  #     file_path
  #   else
  #     (Path[path.dirname] / "#{basename}-#{digest}#{path.extension}").to_s
  #   end
  # end
end
