class PasswordResets::NewPage < AuthLayout
  needs operation : ResetPassword
  needs user_id : Int64

  def page_title
    "设置新密码"
  end

  def content
    op = operation

    section class: "mx-auto w-full max-w-3xl px-8 py-12" do
      article class: "mx-auto overflow-hidden rounded-2xl border border-gray-200 bg-white shadow-sm" do
        div class: "border-b border-gray-200 bg-gradient-to-r from-sky-50 via-white to-cyan-50 px-8 py-7" do
          h1 "设置新密码", class: "text-3xl font-semibold tracking-tight text-gray-900"
          para "请输入新的登录密码，并再次确认。", class: "mt-2 text-sm leading-6 text-gray-600"
        end

        form_for PasswordResets::Create.with(@user_id), class: "space-y-6 px-8 py-8" do
          div class: "mx-auto w-full max-w-sm space-y-6" do
            mount Shared::Field, attribute: op.password, label_text: "密码", &.password_input(autofocus: "true", placeholder: "输入新的登录密码")
            mount Shared::Field, attribute: op.password_confirmation, label_text: "确认密码", &.password_input(placeholder: "再次输入新密码")

            div class: "flex flex-wrap items-center justify-end gap-3 border-t border-gray-200 pt-6" do
              submit "更新密码", class: "form-submit", flow_id: "update-password-button"
            end
          end
        end
      end
    end
  end
end
