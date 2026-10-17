class PasswordResetRequests::NewPage < AuthLayout
  needs operation : RequestPasswordReset

  def page_title : String
    r("common.reset_password").t
  end

  def content : Nil
    op = operation

    auth_page_single_column do
      auth_card(r("common.reset_password").t, r(".description").t) do
        form_for PasswordResetRequests::Create, class: "panel-body" do
          auth_form_fields do
            mount Shared::Field, attribute: op.email, label_text: r("fields.email").t, &.email_input(autofocus: "true", placeholder: "you@example.com")

            auth_form_actions do
              link r(".back_to_sign_in").t, to: SignIns::New, class: "form-secondary"
              submit r(".send_email").t, class: "form-submit", flow_id: "request-password-reset-button"
            end
          end
        end
      end
    end
  end
end
