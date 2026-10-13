module UserLoginName
  # Unique handles use ASCII characters; nicknames remain unrestricted.
  # Like Discourse: allow a leading underscore, require an alphanumeric end,
  # and forbid adjacent separators, including mixed pairs such as ._ or -_.
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
