class SignIns::New < BrowserAction
  include Auth::RedirectSignedInUsers

  param return_to : String?

  get "/sign_in" do
    remember_return_to
    html NewPage, operation: SignInUser.new
  end

  private def remember_return_to : Nil
    return unless (path = ReturnPath.parse(return_to))

    session.set(:return_to, path)
  end
end
