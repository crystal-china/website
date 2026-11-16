class PasswordResetRequests::Create < BrowserAction
  include Auth::RedirectSignedInUsers

  post "/password_reset_requests" do
    RequestPasswordReset.run(params) do |operation, user|
      if user
        begin
          PasswordResetRequestEmail.new(user).deliver
        rescue BaseEmail::NotConfigured
          context.response.headers["HX-Push-Url"] = "false"
          flash.failure = r(".mail_not_configured").t

          return html NewPage, operation: operation
        end

        flash.success = r(".check_email").t
        redirect SignIns::New
      else
        context.response.headers["HX-Push-Url"] = "false"

        html NewPage, operation: operation
      end
    end
  end
end
