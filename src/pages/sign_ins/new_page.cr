class SignIns::NewPage < AuthLayout
  needs operation : SignInUser

  def page_title : String
    r("common.sign_in").t
  end

  def content : Nil
    op = operation

    auth_page_with_oauth do
      auth_card(r("common.sign_in").t, r(".description").t) do
        form_for SignIns::Create, class: "panel-body" do
          auth_form_fields do
            mount(
              Shared::Field,
              attribute: op.login,
              label_text: r("fields.account").t,
              &.text_input(
                autofocus: "true",
                required: "",
                autocomplete: "username"
              )
            )
            mount(
              Shared::Field,
              attribute: op.password,
              label_text: r("fields.password").t,
              &.password_input(required: "", autocomplete: "current-password")
            )

            auth_form_actions do
              link(
                r("common.reset_password").t,
                to: PasswordResetRequests::New,
                class: "form-secondary"
              )

              submit(
                r("common.sign_in").t,
                type: "submit",
                class: "form-submit",
                flow_id: "sign-in-button"
              )
            end
          end
        end
      end
    end
  end
end
