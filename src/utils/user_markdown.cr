module UserMarkdown
  OPTIONS = Markd::Options.new(gfm: true, toc: false)

  def self.render(content : String, formatter : Tartrazine::Formatter = MarkdownFormatter.build) : NamedTuple(html: String, mentions: Array(String))
    # UserMarkdownParser.parse 做的事情：
    # 1. 把合法的 @foo_bar 临时替换为占位符，避免用户名里的 _ 等字符被 Markdown 当作格式语法。
    # 2. Markd::Parser.parse
    # 3. 普通正文保留占位符；代码、已有链接、图片等位置恢复为普通 @zw963，以后不生成提及链接
    # 4. ```info 代码块转换为提示框，其中的 @ 不生成链接或通知。
    document, placeholder, names = UserMarkdownParser.parse(
      content,
      OPTIONS,
      formatter
    )
    html = Markd::HTMLRenderer.new(OPTIONS).render(document, formatter)
    # 先移除不可显示的内容，再生成提及链接和通知名单。
    html = UserHtmlSanitizer.new.process(html)
    html, mentions = add_links(
      html,
      placeholder,
      names
    )

    {html: html, mentions: mentions.to_a}
  end

  private def self.add_links(html : String, placeholder : Regex?, names : Hash(String, String)) : Tuple(String, Set(String))
    linked_names = Set(String).new

    return {html, linked_names} if names.empty?

    html = html.gsub(placeholder.not_nil!) do
      login_name = names[$1]
      login_name_lower = login_name.downcase

      # 页面也只链接前五个不同用户名
      if linked_names.size >= UserMarkdownParser::MAX_MENTIONS && !login_name_lower.in?(linked_names)
        "@#{login_name}"
      else
        linked_names << login_name_lower

        %(<a href="#{HTML.escape(Users::Show.with(login_name: login_name).path)}" rel="nofollow">@#{HTML.escape(login_name)}</a>)
      end
    end

    {html, linked_names}
  end
end
