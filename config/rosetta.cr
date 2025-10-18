@[Rosetta::DefaultLocale(:zh_CN)]
@[Rosetta::AvailableLocales(:en, :zh_CN)]
module Rosetta
end

Rosetta::Lucky.integrate
Rosetta::Backend.load("./config/rosetta")
