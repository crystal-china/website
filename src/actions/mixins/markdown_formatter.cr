module MarkdownFormatter
  def self.build : Tartrazine::Formatter
    Tartrazine::Html.new(
      theme: Tartrazine.theme("catppuccin-macchiato"),
      line_numbers: true,
      standalone: false,
    )
  end

  memoize def formatter : Tartrazine::Formatter
    MarkdownFormatter.build
  end
end
