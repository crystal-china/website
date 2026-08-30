class UserHtmlSanitizer < Sanitize::Policy::HTMLSanitizer
  LINE_NUMBER_STYLE = "user-select: none;"

  def initialize
    super(COMMON_SAFELIST.clone)

    # Tartrazine wraps highlighted tokens in spans. Its line-number style is
    # the only inline style accepted; arbitrary user-provided CSS stays blocked.
    accept_tag("span", Set{"style"})

    Tartrazine::Abbreviations.each_value do |class_name|
      valid_classes << class_name
    end

    valid_classes.concat({"box", "info", "titlebar", "block"})
    valid_classes << /language-.+/
  end

  def transform_attributes(tag : String, attributes : Hash(String, String))
    if tag == "span" && attributes["style"]? != LINE_NUMBER_STYLE
      attributes.delete("style")
    end

    super
  end
end
