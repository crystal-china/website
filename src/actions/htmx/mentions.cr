class Htmx::Mentions < BrowserAction
  param q : String = ""

  get "/htmx/mentions" do
    prefix = q.strip

    return json([] of String) if prefix.empty? || prefix.bytesize > 100

    # LIKE 的通配符必须当普通字符处理，不让输入扩大查询范围。
    prefix = prefix.gsub("\\", "\\\\").gsub("%", "\\%").gsub("_", "\\_")
    names = UserQuery.new.name.like("#{prefix}%").order_by(:name, :asc).limit(8).results.map(&.name)

    json names
  end
end
