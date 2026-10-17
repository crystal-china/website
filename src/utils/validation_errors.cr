# avram.locale.yml 中的字段名称、标准校验和自定义校验共用当前语言。

# attribute_variants:       # 字段名称
# email: "电子邮件"
# 这是 Rosetta 的约定：以 _variants 结尾的翻译组，通过 variant: 选择具体翻译。
# 缺少对应分支就会抛出 VariantMissingException。

# validate_required: "需要的"  # Avram 标准校验消息

# validations:              # 自定义校验消息
# email_not_registered: "不是合法的已注册邮箱地址"

# 对应关系：

# • attribute_variants：由 ValidationErrors.field_name 使用。
# • validate_*：通过 config/database.cr 配置的 Rosetta::AvramBackend，由 Avram 自动调用。
# • validations：由 Operation 中的 Rosetta.find(...).t 调用。

module ValidationErrors
  def self.field_name(name : String | Symbol) : String
    Rosetta.find("avram.attribute_variants").t(variant: name.to_s)
  end

  def self.format(name : String | Symbol, message : String) : String
    Rosetta.find("avram.error").t(field: field_name(name), message: message)
  end
end
