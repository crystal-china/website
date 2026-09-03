class SignUps::Oauth::New < BrowserAction
  include Auth::RedirectSignedInUsers

  get "/multi_auth/:provider" do
    redirect_uri = "#{Lucky::RouteHelper.settings.base_uri}/multi_auth/#{provider}/callback"

    case provider
    when "google"
      scope = "profile email"
    when "github"
      scope = "email"
    end

    state = Random::Secure.hex(32)
    session.set("oauth_state:#{provider}", state)

    authorize_uri = URI.parse(MultiAuth.make(provider, redirect_uri).authorize_uri(scope: scope))

    # 只有 OAuth2 协议才能保证一定在 callback 中回传 state params
    # 例如，twitter 就不支持。
    authorize_uri.query_params = authorize_uri.query_params.tap do |params|
      params["state"] = state
    end

    redirect authorize_uri.to_s
  end
end
