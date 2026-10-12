# 目前仅 avram.locale.yml 被使用。

# 里面又分三部分：

# attribute_variants:       # 字段名称
# email: "电子邮件"
# 这是 Rosetta 的约定：以 _variants 结尾的翻译组，通过 variant: 选择具体翻译。
# 缺少对应分支就会抛出 VariantMissingException。

# validate_required: "需要的"  # Avram 标准校验消息

# errors:                   # 自定义校验消息
# email_not_registered: "不是合法的已注册邮箱地址"

# 对应关系：

# • attribute_variants：由 ValidationErrors.field_name 使用。
# • validate_*：通过 config/database.cr 配置的 Rosetta::AvramBackend，由 Avram 自动调用。
# • errors：由 Operation 中的 Rosetta.find(...).t 调用。

module ValidationErrors
  # Avram 参数解析等入口可能直接生成英文消息；从 YAML 自动构建对应的中文译文。
  MESSAGE_TRANSLATIONS = Hash(String, String).new.tap do |messages|
    {% for translation in Rosetta::Locales.constants %}
      {% if translation.stringify.starts_with?("Avram_Validate") || translation.stringify.starts_with?("Avram_Errors_") %}
        translations = Rosetta::Locales::{{translation.id}}.new.translations
        messages[translations[:en]] = translations[:"zh-CN"]
      {% end %}
    {% end %}
  end

  def self.field_name(name : String | Symbol) : String
    Rosetta.with_locale(:"zh-CN") do
      Rosetta.find("avram.attribute_variants").t(variant: name.to_s)
    end
  end

  def self.format(name : String | Symbol, message : String) : String
    message = MESSAGE_TRANSLATIONS[message]? || message

    "#{field_name(name)} #{message}"
  end
end
