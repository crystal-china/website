class Docs::MarkdownsPage < DocLayout
  def content : Nil
    render_markdown
  end
end
