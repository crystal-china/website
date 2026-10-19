Spec.around_each do |example|
  Rosetta.with_locale(Rosetta.default_locale) { example.run }
end
