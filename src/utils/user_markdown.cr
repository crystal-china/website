module UserMarkdown
  OPTIONS = Markd::Options.new(gfm: true, toc: false)

  def self.render(content : String, formatter : Tartrazine::Formatter = MarkdownFormatter.build)
    document, placeholder, names = UserMarkdownParser.parse(content, OPTIONS, formatter)
    html = Markd::HTMLRenderer.new(OPTIONS).render(document, formatter)
    html, mentions = add_links(html, placeholder, names)
    html = UserHtmlSanitizer.new.process(html)

    {html: html, mentions: mentions.to_a}
  end

  private def self.add_links(html : String, placeholder : Regex?, names : Array(String))
    linked_names = Set(String).new

    return {html, linked_names} if names.empty?

    html = html.gsub(placeholder.not_nil!) do
      login_name = names[$1.to_i]
      login_name_lower = login_name.downcase

      # 页面也只链接前五个不同用户名
      if linked_names.size >= UserMarkdownParser::MAX_MENTIONS && !login_name_lower.in?(linked_names)
        "@#{login_name}"
      else
        linked_names << login_name_lower

        %(<a href="#{HTML.escape(Users::Show.with(login_name: login_name).path)}">@#{HTML.escape(login_name)}</a>)
      end
    end

    {html, linked_names}
  end
end
