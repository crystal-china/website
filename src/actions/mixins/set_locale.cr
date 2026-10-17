module SetLocale
  macro included
    before set_locale
  end

  private def set_locale : Lucky::Response | Lucky::ActionPipes::Continue
    requested_locale = params.get?(:locale)
    locale = requested_locale || session.get?(:locale) || Rosetta.default_locale

    return head 400 unless locale.in?(Rosetta.available_locales)

    Rosetta.locale = locale
    session.set(:locale, locale) if requested_locale

    continue
  end
end
