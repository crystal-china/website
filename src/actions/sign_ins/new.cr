class SignIns::New < BrowserAction
  include Auth::RedirectSignedInUsers

  param return_to : String?

  get "/sign_in" do
    remember_return_to
    html NewPage, operation: SignInUser.new
  end

  private def remember_return_to
    return unless (path = return_to)

    uri = URI.parse(path)
    return unless uri.scheme.nil? && uri.host.nil? && uri.path.starts_with?("/") && !uri.path.includes?('\\')

    session.set(:return_to, uri.request_target)
  rescue URI::Error
  end
end
