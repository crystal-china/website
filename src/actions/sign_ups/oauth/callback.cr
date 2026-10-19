class SignUps::Oauth::Callback < BrowserAction
  include Auth::RedirectSignedInUsers

  get "/multi_auth/:provider/callback" do
    expected_state = session.delete("oauth_state:#{provider}")
    received_state = params.get?(:state)

    return head 400 if expected_state.nil? || received_state.nil?
    return head 400 unless Crypto::Subtle.constant_time_compare(expected_state, received_state)

    redirect_uri = "#{Lucky::RouteHelper.settings.base_uri}/multi_auth/#{provider}/callback"
    auth_user = MultiAuth.make(provider, redirect_uri).user(request.query_params)

    # GitHub 的 nickname 是 login；Google 不提供时，由昵称生成本站唯一标识。
    nickname = (auth_user.name.presence || auth_user.nickname).to_s
    login_name = auth_user.nickname.to_s
    avatar = auth_user.image
    email = auth_user.email.not_nil!

    if (user = UserQuery.new.email(email).first?).nil?
      user = OAuthUser.create!(
        email: email,
        nickname: nickname,
        login_name: login_name,
        avatar: avatar,
      )
    end

    first_oauth_sign_in = !UserAuditQuery.new.user_id(user.id).kind(UserAudit::Kind::OauthSignedIn).any?

    SaveUserAudit.create!(
      user_id: user.id,
      kind: UserAudit::Kind::OauthSignedIn,
      oauth_provider: provider
    )

    if first_oauth_sign_in && user.encrypted_password
      flash.info = r(".password_warning").t
    end

    flash.success = r(".signed_in").t

    sign_in(user)

    Authentic.redirect_to_originally_requested_path(self, fallback: Home::Index)
  end
end
