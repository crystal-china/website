module MarkdownFormatter
  memoize def formatter : Tartrazine::Formatter
    Tartrazine::Html.new(
      theme: Tartrazine.theme("catppuccin-macchiato"),
      line_numbers: true,
      standalone: false,
    )
  end
end
