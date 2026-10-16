@[Rosetta::DefaultLocale(:"zh-CN")]
@[Rosetta::AvailableLocales(:en, :"zh-CN")]
module Rosetta
end

Rosetta::Lucky.integrate
Rosetta::Backend.load("./config/rosetta")

# Avram's type casting still passes a literal English error instead of using
# its backend. Translate that upstream fallback where the error is created.
class Avram::Attribute(T)
  def add_error(message : String = Rosetta.find("avram.validate_format_of").t) : Nil
    previous_def(message == "is invalid" ? Rosetta.find("avram.validate_format_of").t : message)
  end
end

# Rosetta 1.0 predates Avram's URL validator and uses %d for numeric limits.
# Keep the official adapter, adding only the missing URL and decimal support.
struct Rosetta::AvramBackend
  def get(key : String | Symbol) : String
    case key
    when :validate_url_format
      Rosetta.find("avram.validate_url_format").t(scheme: "%s")
    when :validate_numeric_min
      Rosetta.find("avram.validate_numeric_min").t(size: "%s")
    when :validate_numeric_max
      Rosetta.find("avram.validate_numeric_max").t(size: "%s")
    else
      previous_def
    end
  end
end
