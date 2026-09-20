module PageHelpers
  PAGINATION_RELATION_MAPPING = {
    "/docs/index"                                    => {title: "前言", sub_title: "写在开始之前"},
    "/docs/introduction"                             => {title: "简介", sub_title: ""},
    "/docs/install"                                  => {title: "安装", sub_title: ""},
    "/docs/package_manager"                          => {title: "包管理", sub_title: "shards 命令", parent: "/docs/install"},
    "/docs/for_advanced_rubyists"                    => {title: "写给 Rubyists", sub_title: "分类讨论 Crystal 和 Ruby 的异同"},
    "/docs/for_advanced_rubyists/type"               => {title: "类型", sub_title: "", parent: "/docs/for_advanced_rubyists"},
    "/docs/for_advanced_rubyists/method"             => {title: "方法", sub_title: "", parent: "/docs/for_advanced_rubyists"},
    "/docs/for_advanced_rubyists/block"              => {title: "代码块", sub_title: "", parent: "/docs/for_advanced_rubyists"},
    "/docs/for_advanced_rubyists/misc"               => {title: "杂项", sub_title: "", parent: "/docs/for_advanced_rubyists"},
    "/docs/for_advanced_rubyists/performance"        => {title: "性能因素", sub_title: "", parent: "/docs/for_advanced_rubyists"},
    "/docs/for_advanced_rubyists/migrate_to_crystal" => {title: "迁移 Ruby 代码到 Crystal", sub_title: "", parent: "/docs/for_advanced_rubyists"},
    "/docs/basic"                                    => {title: "基础知识", sub_title: "一些基础知识的简单总结"},
    "/docs/profile"                                  => {title: "查找性能瓶颈 (WIP)", sub_title: "", hidden: "true"},
    "/docs/cross_compile"                            => {title: "交叉编译", sub_title: ""},
    "/docs/concurrency"                              => {title: "并发原语", sub_title: ""},
    "/docs/concurrency/execution_context"            => {title: "执行上下文(WIP)", sub_title: "", parent: "/docs/concurrency", hidden: "true"},
    "/docs/concurrency/concurrency_vs_parallelism"   => {title: "并发和并行（比较）", sub_title: "", parent: "/docs/concurrency"},
  }
  PAGINATION_URLS = PAGINATION_RELATION_MAPPING.keys

  record(
    PageMapping,
    name : String,
    path : String,
    parent : String = "root",
    child = [] of PageMapping,
  )

  SIDEBAR_LINKS = {} of String => PageMapping

  PAGINATION_RELATION_MAPPING.each do |k, v|
    parent = v[:parent]? || "root"
    hidden = v[:hidden]?

    if parent == "root"
      SIDEBAR_LINKS[k] = PageMapping.new(
        name: v[:title],
        path: k,
      ) unless hidden == "true"
    else
      if SIDEBAR_LINKS.has_key?(parent)
        SIDEBAR_LINKS[parent].child << PageMapping.new(
          name: v[:title],
          path: k,
        ) unless hidden == "true"
      end
    end
  end

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
