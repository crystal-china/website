class SignUps::NewPage < AuthLayout
  needs operation : SignUpUser

  def page_title : String
    "注册"
  end

  def content : Nil
    op = operation

    auth_page_with_oauth do
      auth_card("注册", "创建新账号并设置登录密码。") do
        form_for SignUps::Create, class: "panel-body" do
          auth_form_fields do
            mount Shared::Field, attribute: op.email, label_text: "电子邮件", &.email_input(autofocus: "true", required: "", placeholder: "you@example.com")

            div class: "space-y-2" do
              div class: "grid gap-5 sm:grid-cols-2" do
                mount(
                  Shared::Field,
                  attribute: op.login_name,
                  label_text: "登录用户名"
                ) do |field|
                  field.text_input(
                    required: "",
                    autocomplete: "username",
                    minlength: UserLoginName::MIN_LENGTH,
                    maxlength: UserLoginName::MAX_LENGTH,
                    placeholder: "用于 @提及"
                  )
                end

                mount(
                  Shared::Field,
                  attribute: op.nickname,
                  label_text: "昵称（可选）"
                ) do |field|
                  field.text_input(placeholder: "留空使用用户名")
                end
              end

              para "登录用户名为 2–20 个字符，以英文字母、数字或 _ 开头，以字母或数字结尾；中间允许 _、-、.，但符号不能相邻，不区分大小写唯一。昵称可以重复，支持中文、空格和 emoji。登录支持邮箱或登录用户名。", class: "m-0 text-xs leading-6 text-gray-500"
            end

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
