module SqlLike
  # LIKE / ILIKE 中，% 匹配任意长度字符，_ 匹配单个字符；将用户输入当普通文字处理。
  # Hash 替换只扫描原文一次，不会再次转义替换结果中的反斜杠。
  def self.escape(value : String) : String
    value.gsub({'\\' => "\\\\", '%' => "\\%", '_' => "\\_"})
  end
end
