module UserMentions
  def self.user_ids(content : String) : Array(Int64)
    names = [] of String
    walker = Markd::Parser.parse(content, Markd::Options.new(gfm: true)).walker

    # 只检查 Markdown 文本节点，跳过代码节点、链接 URL 和原始 HTML 节点。
    while (event = walker.next)
      node, entering = event
      next unless entering && node.type.text?

      node.text.scan(/(?<![A-Za-z0-9_@])@([^\s\p{Z}<>`,，。!！?？:：;；]+)/) do |match|
        names << match[1]
        names.uniq!
        break if names.size >= 20
      end
      # 限制候选数，避免超长正文生成巨大的 SQL IN 列表。
      break if names.size >= 20
    end

    return [] of Int64 if names.empty?

    users = UserQuery.new.name.in(names.flat_map { |name| [name, name.rstrip(".")] }.uniq).results
    ids = [] of Int64
    names.each do |name|
      # 优先精确匹配；末尾句点只有在不属于用户名时才视为标点。
      user = users.find { |user| user.name == name } || users.find { |user| user.name == name.rstrip(".") }
      ids << user.id if user && !ids.includes?(user.id)
      break if ids.size == 5
    end

    ids
  end
end
