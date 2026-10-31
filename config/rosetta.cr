@[Rosetta::DefaultLocale(:"zh-CN")]
@[Rosetta::AvailableLocales(:en, :"zh-CN")]
module Rosetta
end

Rosetta::Lucky.integrate
Rosetta::Backend.load("./config/rosetta")
