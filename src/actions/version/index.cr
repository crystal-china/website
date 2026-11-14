class Version::Index < BrowserAction
  get "/version" do
    built_at = App::BUILT_AT.in(context.time_zone)

    plain_text "#{App::VERSION} #{built_at.to_s("%Y-%m-%d %H:%M:%S %z")}"
  end
end
