class Htmx::SignUps::Captcha < BrowserAction
  include Auth::AllowGuests

  param width : String?
  param height : String?

  post "/htmx/signups/captcha" do
    signup_captcha_id = Random.base58(10)
    cookies.set("signup_captcha_id", signup_captcha_id)
    captcha = CaptchaGenerator.new

    CAPTCHA_CACHE.write(signup_captcha_id, captcha.code)

    plain_text <<-HEREDOC
<span
id="signup_captcha"
class="inline-flex w-[11rem] shrink-0 cursor-pointer justify-center rounded-xl bg-sky-50 px-5 py-2.5 text-sm font-medium text-sky-700 transition hover:bg-sky-100"
hx-post="#{Htmx::SignUps::Captcha.path}"
hx-target="#signup_captcha"
hx-swap="outerHTML"
>
#{captcha.img_tag(height: "35px")}
</span>
HEREDOC
  end
end
