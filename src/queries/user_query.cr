class UserQuery < User::BaseQuery
  def with_login_name(value : String) : self
    where("login_name_lower = lower(?)", value)
  end

  def with_login_name_prefix(prefix : String) : self
    # LIKE 的通配符必须当普通字符处理，不让输入扩大查询范围。
    # 转义 like 查询中作为特殊字符的字符。% 任意长度字符，_ 任意单个字符
    # 顺序是刻意地，不能先给 % 或 _ 加了转义再替换 \。
    prefix = prefix.gsub("\\", "\\\\").gsub("%", "\\%").gsub("_", "\\_")

    where("login_name_lower LIKE lower(?)", "#{prefix}%")
  end

  def with_login_names(values : Array(String)) : self
    return where("FALSE") if values.empty?

    placeholders = Array.new(values.size, "lower(?)").join(", ")

    where("login_name_lower IN (#{placeholders})", args: values)
  end
end
