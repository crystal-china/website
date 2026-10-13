module UserLoginName
  # Unique handles use ASCII characters; nicknames remain unrestricted.
  # Like Discourse: allow a leading underscore, require an alphanumeric end,
  # and forbid adjacent separators, including mixed pairs such as ._ or -_.
  # 校验整个登录用户名：仅允许 ASCII 字母、数字、_、.、-；以字母、数字或 _ 开头，
  # 多字符用户名必须以字母或数字结尾；特殊符号不能连续出现（如 __、._、-_）。
  # 例如 _zw_963、a_b_c、some.user 合法，.abc、abc_、a__b 不合法。
  # 正则也接受单个字母、数字或 _；valid? 另行限制长度为 2 到 20 个字符。
  FORMAT     = /\A(?!.*[_.-]{2})[A-Za-z0-9_](?:[A-Za-z0-9_.-]*[A-Za-z0-9])?\z/
  MIN_LENGTH =  2
  MAX_LENGTH = 20

  def self.valid?(value : String) : Bool
    FORMAT.matches?(value) && value.size.in?(MIN_LENGTH..MAX_LENGTH)
  end

  def self.generate(preferred : String? = nil) : String
    # 删除非法的字符。
    base = preferred.to_s.gsub(/[^A-Za-z0-9_.-]+/, "")
    base = base.sub(/\A[.-]+/, "").gsub(/[_.-]{2,}/, "_")
    # 注意，只要截断一次，就有可能非法字符结尾，就必须再 rstrip 一次。
    base = base[0, MAX_LENGTH].rstrip("._-")

    if base.size < MIN_LENGTH
      base = "Crystalist"
      candidate = "#{base}_#{rand(100000..999999)}"
    else
      candidate = base
    end

    while UserQuery.new.with_login_name(candidate).any?
      # Reserve seven characters for the underscore and six-digit suffix.
      candidate = "#{base[0, MAX_LENGTH - 7].rstrip("._-")}_#{rand(100000..999999)}"
    end

    candidate
  end
end
