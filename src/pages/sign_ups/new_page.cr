class SignUps::NewPage < AuthLayout
  needs operation : SignUpUser

  def page_title
    "注册"
  end

  def content
    op = operation

    section class: "mx-auto grid w-full max-w-4xl gap-8 px-8 py-12 lg:grid-cols-[minmax(0,1fr)_18rem]" do
      article class: "overflow-hidden rounded-2xl border border-gray-200 bg-white shadow-sm" do
        div class: "border-b border-gray-200 bg-gradient-to-r from-sky-50 via-white to-cyan-50 px-8 py-7" do
          h1 "注册", class: "text-3xl font-semibold tracking-tight text-gray-900"
          para "创建新账号并设置登录密码。完成后即可使用邮箱、密码或第三方账号登录。", class: "mt-2 text-sm leading-6 text-gray-600"
        end

        form_for SignUps::Create, class: "space-y-6 px-8 py-8" do
          div class: "mx-auto w-full max-w-sm space-y-6" do
            mount Shared::Field, attribute: op.email, label_text: "电子邮件", &.email_input(autofocus: "true", required: "", placeholder: "you@example.com")
            mount Shared::Field, attribute: op.password, label_text: "密码", &.password_input(required: "", placeholder: "设置登录密码")
            mount Shared::Field, attribute: op.password_confirmation, label_text: "确认密码", &.password_input(required: "", placeholder: "再次输入密码")

            div class: "form-field" do
              label "人机验证码", for: "captcha", class: "form-label"

              div class: "flex flex-wrap items-center gap-3" do
                input(
                  type: "text",
                  id: "captcha",
                  name: "captcha",
                  flow_id: "captcha",
                  required: "",
                  autocomplete: "off",
                  placeholder: "输入图片中的字符",
                  class: "form-input min-w-0 flex-1"
                )

                span(
                  id: "signup_captcha",
                  class: "inline-flex w-[11rem] shrink-0 cursor-pointer justify-center rounded-xl bg-sky-50 px-5 py-2.5 text-sm font-medium text-sky-700 transition hover:bg-sky-100",
                  hx_post: Htmx::SignUps::Captcha.path_without_query_params,
                  hx_target: "#signup_captcha",
                  hx_swap: "outerHTML"
                ) do
                  text "点击获取人机验证码"
                end
              end

              mount Shared::FieldErrors, op.captcha_code
            end

            div class: "flex flex-wrap items-center justify-between gap-3 border-t border-gray-200 pt-6" do
              link "已有账号？去登录", to: SignIns::New, class: "form-secondary"

              submit "注册", type: "submit", flow_id: "sign-up-button", class: "form-submit"
            end
          end
        end
      end

      mount Component::OAuth
    end
  end
end
