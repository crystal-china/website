module UserMarkdownParser
  # 提取 @登录用户名候选，供 UserMarkdownParser 使用；捕获组 1 是用户名，不含 @。
  # @ 前不能紧接 ASCII 字母、数字或 @；用户名以字母、数字或 _ 开头，
  # 中间允许字母、数字、_、.、-，以字母或数字结尾；中文可直接跟在用户名后面。
  # 长度和连续特殊符号等完整规则由 UserLoginName.valid? 校验。

  # (?<![A-Za-z0-9@])@ 意思是：找到一个 @，但它前面不能紧接英文字母、数字或另一个 @。
  # (?<!...) 是否定后向断言：检查当前位置前面，不能匹配括号里的规则，但不把前面的字符算进匹配结果
  PATTERN      = /(?<![A-Za-z0-9@])@([A-Za-z0-9_][A-Za-z0-9_.-]*[A-Za-z0-9])/
  MAX_MENTIONS = 5

  RAW_TAG_NAMES = /(a|code|pre|script|style|textarea|title)/
  # 这里，/.../ 看成创建一个 Regex 对象的写法，
  # regex = /abc/i
  # .source：只取匹配内容，返回字符串 => abc
  # .to_s # => "(?i-msx:abc)"，包含默认选项。
  RAW_OPEN_TAG  = /\A<\s*#{RAW_TAG_NAMES.source}\b/i
  RAW_CLOSE_TAG = /\A<\s*\/\s*#{RAW_TAG_NAMES.source}\s*>/i

  # 筛选允许生成提及链接的位置，同时转换 info 提示框；不查询用户，也不发送通知。
  def self.parse(content : String, options : Markd::Options, formatter : Tartrazine::Formatter) : Tuple(Markd::Node, Regex?, Hash(String, String))
    names = {} of String => String
    source = content
    placeholder = nil

    if content.includes?('@')
      # 临时占位符避免 @ 用户名被 Markdown 的下划线或 GFM 自动链接拆开。
      # 只处理渲染副本；数据库仍保存用户输入的原文。
      prefix = "USERMENTION#{Random::Secure.hex(8)}TOKEN"
      # 0 只按 00、01、0v、0V 读取，因此结尾的 0E 不会被当成用户名编码。
      placeholder = /#{prefix}((?:[A-Za-z1-9.-]|0[01vV])+)0E/
      offset = 0

      # content = "你好 @zw963，再问 @xiaoming。"
      # 下面这段代码会把上面的内容转化为：
      # source = "你好 TOKEN<zw963的编码>0E，再问 TOKEN<xiaoming的编码>0E。" (示意，省略随机前缀)
      # names 保存编码到原用户名的对应关系。
      # 同名使用相同占位符；保留字母大小写，让引用式链接仍按 Markdown 规则匹配。
      source = String.build do |io|
        content.scan(PATTERN) do |match|
          next unless UserLoginName.valid?(match[1])
          next if content[match.end]? == '@'
          next if escaped?(content, match.begin)

          encoded_name = encode_login_name(match[1])

          io << content[offset...match.begin]
          io << prefix << encoded_name << "0E"
          names[encoded_name] = match[1]
          offset = match.end
        end

        io << content[offset..]
      end
    end

    # 这里开始 markdown 解析流程。
    document = Markd::Parser.parse(source, options)

    if names.empty? && !content.includes?("```") && !content.includes?("~~~")
      return {document, placeholder, names}
    end

    link_depth = 0
    raw_tag_stack = [] of String
    walker = document.walker

    while (event = walker.next)
      node, entering = event

      # info 是提示框，不生成提及链接或通知。
      if entering && node.type.code_block? && node.fence_language == "info"
        node.text = restore_mentions(node.text, placeholder, names) unless names.empty?
        MarkdownInfoBox.convert(node, options, formatter)
        next
      end

      next if names.empty?

      if node.type.link? || node.type.image?
        # entering 表示进入或离开 Markd 节点，不是 HTML 标签的开闭
        # 手写 HTML 的开始、结束标签是两个独立的叶子节点
        link_depth += entering ? 1 : -1
      end

      # 原始 HTML 的链接、代码及纯文本容器不生成提及链接。
      # 后者可能被 sanitizer 移除，不能因此发送没有对应链接的通知。

      # 是不是原始 HTML 标签节点：
      if node.type.html_inline?
        # 判断开始标签。例如：<a> <code>
        if (tag = node.text.match(RAW_OPEN_TAG))
          # 将标签名，例如：a, code 加入 raw_tag_stack
          raw_tag_stack << tag[1].downcase
          # 否则判断是不是结束标签, </a> </code>
        elsif (tag = node.text.match(RAW_CLOSE_TAG))
          # tag1 仍然是 a, code, 如果有成对儿的标签，pop
          # ["a", "code"] + </code> → ["a"]
          # ["a"]         + </a>    → []
          raw_tag_stack.pop? if raw_tag_stack.last? == tag[1].downcase
        end
      end

      # raw_tag_stack 如果不为空，表示仍然在标签内部。
      # 因此 raw_tag_stack.empty? 表示跳出了标签。
      # 这里全是合法的 text 节点时，保留占位符，稍后在 HTML 中生成链接。
      unless entering && node.type.text? && link_depth.zero? && raw_tag_stack.empty?
        # 如果不满足，全部把占位符恢复成 @user
        node.text = restore_mentions(node.text, placeholder, names)
      end

      # GPT 核对了 Node 定义 (lib/markd/src/markd/node.cr:60) 和 HTML 渲染器。

      # • node.text：正文、代码内容、原始 HTML 等。
      # • node.data 的字符串值：链接/图片地址、标题等。
      # • node.fence_language：代码块的语言标识或信息。

      # 只有这三处地方可能包含 @???, 后两处这里也单独替换。
      node.data.transform_values! do |value|
        value.is_a?(String) ? restore_mentions(value, placeholder, names) : value
      end
      node.fence_language = restore_mentions(node.fence_language, placeholder, names)
    end

    # 到这里，只有合法的地方的 @user 声明还是占位符，其他已经恢复。

    {document, placeholder, names}
  end

  private def self.escaped?(content : String, position : Int32) : Bool
    count = 0
    index = position - 1

    while index >= 0 && content[index] == '\\'
      count += 1
      index -= 1
    end

    # 成对的反斜杠表示普通反斜杠；剩下一个才会转义 @。
    count.odd?
  end

  private def self.encode_login_name(login_name : String) : String
    # 编码规则：将会被 Markdown 特殊处理的字符转码保存。
    # 原字符    编码
    # ━━━━━━━━  ━━━━━━
    # 0         00   因为所有编码都包含 0 作为转义字符标记，因此，login_name 里面的 0 需要转义。
    # ────────  ──────
    # _         01
    # ────────  ──────
    # w         0v w 这里会被 markd 作为 www 开头的链接特殊处理。
    # ────────  ──────
    # W         0V  确保大小写 w 和 W 原样恢复, v 这个字符随便选的一个无特殊意义的字符。
    login_name.gsub({
      '0' => "00",
      '_' => "01",
      'w' => "0v",
      'W' => "0V",
    })
  end

  private def self.restore_mentions(text : String, placeholder : Regex?, names : Hash(String, String)) : String
    text.gsub(placeholder.not_nil!) { "@#{names[$1]}" }
  end
end
