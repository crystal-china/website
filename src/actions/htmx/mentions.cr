class Htmx::Mentions < BrowserAction
  param q : String = ""

  get "/htmx/mentions" do
    prefix = q.strip

    return json([] of String) if prefix.empty? || prefix.bytesize > 100

    # LIKE 的通配符必须当普通字符处理，不让输入扩大查询范围。
    # 转义 like 查询中作为特殊字符的字符。% 任意长度字符，_ 任意单个字符
    # 顺序是刻意地，不能先给 % 或 _ 加了转义再替换 \。
    prefix = prefix.gsub("\\", "\\\\").gsub("%", "\\%").gsub("_", "\\_")
    names = UserQuery.new.mention_notifications_enabled(true).name.like("#{prefix}%").order_by(:name, :asc).limit(8).results.map(&.name)

    json names
  end
end
