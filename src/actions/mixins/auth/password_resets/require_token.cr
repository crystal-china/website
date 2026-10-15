module Auth::PasswordResets::RequireToken
  macro included
    before require_valid_password_reset_token
  end

  abstract def token : String
  abstract def user : User

  private def require_valid_password_reset_token : Lucky::Response | Lucky::ActionPipes::Continue
    if Authentic.valid_password_reset_token?(user, token)
      continue
    else
      flash.failure = "密码重置链接已过期，请重新发送"
      redirect to: PasswordResetRequests::New
    end
  end
end
