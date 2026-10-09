module UserMentions
  def self.user_ids(content : String) : Array(Int64)
    names = Set(String).new
    walker = Markd::Parser.parse(content, Markd::Options.new(gfm: true)).walker

    # 只检查 Markdown 文本节点，跳过代码节点、链接 URL 和原始 HTML 节点。
    while (event = walker.next)
      node, entering = event
      next unless entering && node.type.text?

      node.text.scan(/(?<![A-Za-z0-9_@])@([^\s\p{Z}<>`,，。!！?？:：;；]+)/) do |match|
        names << match[1]
        break if names.size >= 20
      end
      # 限制候选数，避免超长正文生成巨大的 SQL IN 列表。
      break if names.size >= 20
    end

    return [] of Int64 if names.empty?

    UserQuery.new.name.in(names.to_a).id.asc_order.limit(5).results.map(&.id)
  end
end
