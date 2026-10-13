module UserLoginName
  # Unique handles use ASCII characters; nicknames remain unrestricted.
  FORMAT     = /\A[A-Za-z0-9_.-]+\z/
  MIN_LENGTH =  2
  MAX_LENGTH = 20

  def self.generate(preferred : String? = nil) : String
    # 删除非法的字符。
    base = preferred.to_s.gsub(/[^A-Za-z0-9_.-]+/, "")[0, MAX_LENGTH]

    base = "User#{rand(100000..999999)}" if base.size < MIN_LENGTH
    candidate = base

    while UserQuery.new.with_login_name(candidate).any?
      # Reserve seven characters for the underscore and six-digit suffix.
      candidate = "#{base[0, MAX_LENGTH - 7]}_#{rand(100000..999999)}"
    end

    candidate
  end
end
