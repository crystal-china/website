class PasswordResetRequests::NewPage < AuthLayout
  needs operation : RequestPasswordReset

  def page_title
    "重置密码"
  end

  def content
    op = operation

    auth_page_single_column do
      auth_card("重置密码", "输入注册邮箱，我们会向你发送一封包含重置链接的邮件。") do
        form_for PasswordResetRequests::Create, class: "px-8 py-8" do
          auth_form_fields do
            mount Shared::Field, attribute: op.email, label_text: "电子邮件", &.email_input(autofocus: "true", placeholder: "you@example.com")

            auth_form_actions do
              link "返回登录", to: SignIns::New, class: "form-secondary"
              submit "发送重置邮件", class: "form-submit", flow_id: "request-password-reset-button"
            end
          end
        end
      end
    end
  end
end
