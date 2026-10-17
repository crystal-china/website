class PasswordResets::NewPage < AuthLayout
  needs operation : ResetPassword
  needs user_id : Int64

  def page_title : String
    r(".page_title").t
  end

  def content : Nil
    op = operation

    auth_page_single_column do
      auth_card(r(".page_title").t, r(".description").t) do
        form_for PasswordResets::Create.with(@user_id), class: "panel-body" do
          auth_form_fields do
            mount Shared::Field, attribute: op.password, label_text: r("fields.password").t, &.password_input(autofocus: "true", placeholder: r(".password_placeholder").t)
            mount Shared::Field, attribute: op.password_confirmation, label_text: r("fields.password_confirmation").t, &.password_input(placeholder: r(".confirmation_placeholder").t)

            auth_form_actions(justify: "justify-end") do
              submit r(".update_password").t, class: "form-submit", flow_id: "update-password-button"
            end
          end
        end
      end
    end
  end
end
