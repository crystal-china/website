class Version::Index < BrowserAction
  get "/version" do
    plain_text App::VERSION
  end
end
