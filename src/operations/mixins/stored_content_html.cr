module StoredContentHtml
  # 本次渲染实际生成链接的用户名；仅供保存后的通知使用，不写入数据库。
  getter mentioned_login_names = [] of String

  macro included
    before_save generate_content_html
  end

  private def generate_content_html : Nil
    # avram 默认把空字符串，纯白字符当作 nil，让这个字段可以接受 "" 空字符串
    content_html.allow_blank = true

    return unless content.changed? && (source = content.value)

    rendered = UserMarkdown.render(source)
    content_html.value = rendered[:html]
    @mentioned_login_names = rendered[:mentions]
  end

  def changes : Hash(Symbol, String?)
    fields = super
    # 正文 UPDATE 也必须携带本次生成的 HTML，避免旧对象保存时留下不配套的内容。
    fields[:content_html] = content_html.value if fields.has_key?(:content)

    fields
  end
end
