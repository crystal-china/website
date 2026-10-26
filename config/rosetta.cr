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
