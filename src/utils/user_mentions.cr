module UserMentions
  # 提取 @登录用户名候选，供通知提取和页面链接生成共用；捕获组 1 是用户名，不含 @。
  # @ 前不能紧接 ASCII 字母、数字或 @；用户名以字母、数字或 _ 开头，
  # 中间允许字母、数字、_、.、-，以字母或数字结尾；中文可直接跟在用户名后面。
  # 长度和连续特殊符号等完整规则由 UserLoginName.valid? 校验。

  # (?<![A-Za-z0-9@])@ 意思是：找到一个 @，但它前面不能紧接英文字母、数字或另一个 @。
  # (?<!...) 是否定后向断言：检查当前位置前面，不能匹配括号里的规则，但不把前面的字符算进匹配结果
  PATTERN = /(?<![A-Za-z0-9@])@([A-Za-z0-9_][A-Za-z0-9_.-]*[A-Za-z0-9])/

  def self.user_ids(content : String) : Array(Int64)
    _, login_names = UserMentionMarkdown.parse(content)

    return [] of Int64 if login_names.empty?

    UserQuery.new.with_login_names(login_names.to_a).id.asc_order.results.map(&.id)
  end

  # 通知提取和页面链接使用同一套提及边界与用户名规则。
  def self.each_mention(text : String, &)
    text.scan(PATTERN) do |match|
      next unless UserLoginName.valid?(match[1])
      next if text[match.end]? == '@'

      yield match
    end
  end
end
