require "rosetta"

@[Rosetta::DefaultLocale(:en)]
@[Rosetta::AvailableLocales(:en, :"zh-CN")]
module Rosetta
end

Rosetta::Backend.load("spec/fixtures/i18n/missing_locale/config")
