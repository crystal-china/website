class SignIns::NewPage < AuthLayout
  needs operation : SignInUser

  def page_title
    "登录"
  end

  def content
    op = operation

    auth_page_with_oauth do
      auth_card("登录", "使用邮箱和密码登录你的账号。") do
        form_for SignIns::Create, class: "panel-body" do
          auth_form_fields do
            mount Shared::Field, attribute: op.email, label_text: "电子邮件", &.email_input(autofocus: "true")
            mount Shared::Field, attribute: op.password, label_text: "密码", &.password_input

            auth_form_actions do
              submit "登录", type: "submit", class: "form-submit", flow_id: "sign-in-button"

              link "重置密码", to: PasswordResetRequests::New, class: "form-secondary"
            end
          end
        end
      end
    end
  end
end
