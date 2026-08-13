class SignIns::NewPage < AuthLayout
  needs operation : SignInUser

  def page_title
    "登录"
  end

  def content
    op = operation
    section class: "mx-auto grid w-full max-w-4xl gap-8 px-8 py-12 lg:grid-cols-[minmax(0,1fr)_18rem]" do
      article class: "overflow-hidden rounded-2xl border border-gray-200 bg-white shadow-sm" do
        div class: "border-b border-gray-200 bg-gradient-to-r from-sky-50 via-white to-cyan-50 px-8 py-7" do
          h1 "登录", class: "text-3xl font-semibold tracking-tight text-gray-900"
          para "使用邮箱和密码登录你的账号。", class: "mt-2 text-sm leading-6 text-gray-600"
        end

        form_for SignIns::Create, class: "space-y-6 px-8 py-8" do
          div class: "mx-auto w-full max-w-sm space-y-6" do
            mount Shared::Field, attribute: op.email, label_text: "电子邮件", &.email_input(autofocus: "true")
            mount Shared::Field, attribute: op.password, label_text: "密码", &.password_input

            div class: "flex flex-wrap items-center justify-between gap-3 border-t border-gray-200 pt-6" do
              link "重置密码", to: PasswordResetRequests::New, class: "form-secondary"

              submit "登录", type: "submit", class: "form-submit", flow_id: "sign-in-button"
            end
          end
        end
      end

      mount Component::OAuth
    end
  end
end
