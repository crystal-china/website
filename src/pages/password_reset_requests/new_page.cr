class PasswordResetRequests::NewPage < AuthLayout
  needs operation : RequestPasswordReset

  def page_title
    "重置密码"
  end

  def content
    op = operation

    section class: "mx-auto w-full max-w-3xl px-8 py-12" do
      article class: "mx-auto overflow-hidden rounded-2xl border border-gray-200 bg-white shadow-sm" do
        div class: "border-b border-gray-200 bg-gradient-to-r from-sky-50 via-white to-cyan-50 px-8 py-7" do
          h1 "重置密码", class: "text-3xl font-semibold tracking-tight text-gray-900"
          para "输入注册邮箱，我们会向你发送一封包含重置链接的邮件。", class: "mt-2 text-sm leading-6 text-gray-600"
        end

        form_for PasswordResetRequests::Create, class: "space-y-6 px-8 py-8" do
          div class: "mx-auto w-full max-w-sm space-y-6" do
            mount Shared::Field, attribute: op.email, label_text: "电子邮件", &.email_input(autofocus: "true", placeholder: "you@example.com")

            div class: "flex flex-wrap items-center justify-between gap-3 border-t border-gray-200 pt-6" do
              link "返回登录", to: SignIns::New, class: "form-secondary"
              submit "发送重置邮件", class: "form-submit", flow_id: "request-password-reset-button"
            end
          end
        end
      end
    end
  end
end
