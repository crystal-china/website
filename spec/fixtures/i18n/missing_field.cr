require "./bootstrap"

# 这是一个故意编译失败的测试文件，用来确认翻译键拼错或遗漏时，Rosetta 会在编译阶段报错
Rosetta.find("fields.missing_field_for_compile_test").t
