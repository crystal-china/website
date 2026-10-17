require "rosetta"

@[Rosetta::DefaultLocale(:"zh-CN")]
@[Rosetta::AvailableLocales(:en, :"zh-CN")]
module Rosetta
end

Rosetta::Backend.load("config/rosetta")
