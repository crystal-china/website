class SignIns::Create < BrowserAction
  include Auth::RedirectSignedInUsers

  post "/sign_in" do
    SignInUser.run(params) do |operation, authenticated_user|
      if authenticated_user
        sign_in(authenticated_user)
        flash.success = r(".signed_in").t
        Authentic.redirect_to_originally_requested_path(self, fallback: Home::Index)
      else
        flash.failure = r(".sign_in_failed").t
        html NewPage, operation: operation
      end
    end
  end
end
