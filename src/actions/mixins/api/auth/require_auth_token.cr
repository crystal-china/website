module Api::Auth::RequireAuthToken
  macro included
    before require_auth_token
  end

  private def require_auth_token : Lucky::Response | Lucky::ActionPipes::Continue
    if current_user?
      continue
    else
      json auth_error_json, 401
    end
  end

  private def auth_error_json : ErrorSerializer
    ErrorSerializer.new(
      message: r("api.auth.require_auth_token.not_authenticated").t,
      details: auth_error_details
    )
  end

  private def auth_error_details : String
    if auth_token
      r("api.auth.require_auth_token.token_invalid").t
    else
      r("api.auth.require_auth_token.token_missing").t
    end
  end

  # Tells the compiler that the current_user is not nil since we have checked
  # that the user is signed in
  private def current_user : User
    current_user?.as(User)
  end
end
