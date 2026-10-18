require "../../utils/doc_navigation"

module PageHelpers
  MARKDOWN_OPTIONS = Markd::Options.new(gfm: true, toc: true)

  def relative_time(at : Time) : String
    if Rosetta.locale == "en"
      TimeInWords::Helpers(TimeInWords::I18n::EN).from(time: at)
    else
      TimeInWords::Helpers(TimeInWords::I18n::ZH_CN).from(time: at)
    end
  end

  def time_in_zone(at : Time) : Time
    at.in(context.time_zone)
  end

  # at 用来生成 hover 时间，label 用来传递字符串，直接在页面显示。
  def local_time(at : Time, label : String, **attrs) : Nil
    time(
      label,
      **attrs,
      datetime: at.to_rfc3339, # 这个只是一个冗余，显示准确地 UTC 时间。
      # title 会在鼠标 hover 时显示；统一使用本次请求的浏览器时区，缺失时以服务器时区兜底。
      # 浏览器只保存时区 Cookie，不再逐个转换页面上的时间标签。
      title: time_in_zone(at).to_s("%Y-%m-%d %H:%M:%S %z")
    )
  end

  def doc_markdown(text) : String
    render_markdown_with_info_boxes(text)
  end

  # User-authored Markdown may contain raw HTML, so sanitize the rendered HTML
  # before inserting it into the page. Trusted documentation uses #doc_markdown.
  def user_markdown(text) : String
    UserMarkdown.render(text, formatter)[:html]
  end

  def current_path : String
    context.request.path
  end

  def canonical_url : String
    "#{Lucky::RouteHelper.settings.base_uri}#{current_path}"
  end

  private def render_markdown_with_info_boxes(text : String, options = MARKDOWN_OPTIONS) : String
    if !text.includes?("```") && !text.includes?("~~~")
      return Markd.to_html(text, options: options, formatter: formatter)
    end

    document = Markd::Parser.parse(text, options)
    walker = document.walker

    while (event = walker.next)
      node, entering = event

      next unless entering && node.type.code_block? && node.fence_language == "info"

      MarkdownInfoBox.convert(node, options, formatter)
    end

    Markd::HTMLRenderer.new(options).render(document, formatter)
  end

  private def show_comments_when_revealed(comment_thread_id : Int64) : Nil
    focus_id = context.request.query_params["comment_id"]?.try(&.to_i64?)
    trigger = focus_id ? "load" : (context.request.headers["Referer"]? ? "revealed" : "load")
    path = Htmx::Comments::Index.with(comment_thread_id: comment_thread_id, comment_id: focus_id).path

    div(
      role: "feed",
      id: "comments",
      hx_get: path,
      hx_trigger: trigger,
      hx_swap: "outerHTML"
    ) do
      mount Shared::Spinner, text: r("common.loading_comments").t
    end
  end

  private def page_container_classes : String
    "#{page_frame_classes} #{page_gutter_classes}"
  end

  private def page_frame_classes : String
    "mx-auto w-full max-w-7xl"
  end

  private def page_gutter_classes : String
    "px-4 sm:px-6 lg:px-8"
  end

  private def htmx_success(script) : String
    <<-HEREDOC
on htmx:after:request(ctx)[ctx.response.raw.ok]
#{script}
end
HEREDOC
  end

  # 背景点击的 target 也是 dialog；检查坐标，避免点击内部空白时关闭。
  private def dialog_outside_click(action : String) : String
    <<-HYPER
on click[target is me]
  set bounds to my.getBoundingClientRect()
  if event.clientX < bounds.left or event.clientX > bounds.right or event.clientY < bounds.top or event.clientY > bounds.bottom
    #{action}
  end
end
HYPER
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
