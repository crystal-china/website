class SignUps::Create < BrowserAction
  include Auth::RedirectSignedInUsers

  post "/sign_up" do
    signup_captcha_id = cookies.get?("signup_captcha_id")

    return sign_up(params, r(".invalid_captcha").t) if signup_captcha_id.nil?

    captcha_input = params.get?(:captcha)

    return sign_up(params, r(".invalid_captcha").t) if captcha_input.nil?

    signup_captcha_code = CAPTCHA_MUTEX.synchronize do
      code = CAPTCHA_CACHE.read(signup_captcha_id)

      next if code.nil?
      next if captcha_input.downcase != code.downcase

      CAPTCHA_CACHE.delete(signup_captcha_id)
      code
    end

    return sign_up(params, r(".invalid_captcha").t) if signup_captcha_code.nil?

    cookies.delete("signup_captcha_id")

    sign_up(
      params,
      r(".sign_up_failed").t,
      signup_captcha_code
    )
  end

  def sign_up(params, flash_msg, captcha_code : String = "") : Lucky::Response
    SignUpUser.create(params, captcha_code: captcha_code) do |operation, user|
      if user
        flash.info = r(".signed_up").t
        sign_in(user)
        redirect to: Home::Index
      else
        flash.failure = flash_msg
        html NewPage, operation: operation
      end
    end
  end
end
