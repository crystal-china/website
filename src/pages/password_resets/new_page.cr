class PasswordResets::NewPage < AuthLayout
  needs operation : ResetPassword
  needs user_id : Int64

  def page_title
    "设置新密码"
  end

  def content
    op = operation

    auth_page_single_column do
      auth_card("设置新密码", "请输入新的登录密码，并再次确认。") do
        form_for PasswordResets::Create.with(@user_id), class: "px-8 py-8" do
          auth_form_fields do
            mount Shared::Field, attribute: op.password, label_text: "密码", &.password_input(autofocus: "true", placeholder: "输入新的登录密码")
            mount Shared::Field, attribute: op.password_confirmation, label_text: "确认密码", &.password_input(placeholder: "再次输入新密码")

            auth_form_actions(justify: "justify-end") do
              submit "更新密码", class: "form-submit", flow_id: "update-password-button"
            end
          end
        end
      end
    end
  end
end
