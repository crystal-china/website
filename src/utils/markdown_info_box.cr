module MarkdownInfoBox
  def self.convert(node : Markd::Node, options : Markd::Options, formatter : Tartrazine::Formatter)
    node.type = :html_block
    node.text = <<-HTML
    <div class="box info">
      <strong class="titlebar block">💡 小提示</strong>
      #{Markd.to_html(node.text, options: options, formatter: formatter)}
    </div>
    HTML
  end
end
