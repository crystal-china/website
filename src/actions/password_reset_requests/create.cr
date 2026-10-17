class PasswordResetRequests::Create < BrowserAction
  include Auth::RedirectSignedInUsers

  post "/password_reset_requests" do
    RequestPasswordReset.run(params) do |operation, user|
      if user
        PasswordResetRequestEmail.new(user).deliver
        flash.success = r(".check_email").t
        redirect SignIns::New
      else
        html NewPage, operation: operation
      end
    end
  end
end
