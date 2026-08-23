class SignUps::NewPage < AuthLayout
  needs operation : SignUpUser

  def page_title
    "注册"
  end

  def content
    op = operation

    auth_page_with_oauth do
      auth_card("注册", "创建新账号并设置登录密码。完成后即可使用邮箱、密码或第三方账号登录。") do
        form_for SignUps::Create, class: "px-8 py-8" do
          auth_form_fields do
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

            auth_form_actions do
              link "已有账号？去登录", to: SignIns::New, class: "form-secondary"

              submit "注册", type: "submit", flow_id: "sign-up-button", class: "form-submit"
            end
          end
        end
      end
    end
  end
end
