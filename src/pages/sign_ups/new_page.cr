class SignUps::NewPage < AuthLayout
  needs operation : SignUpUser

  def page_title : String
    r("common.sign_up").t
  end

  def content : Nil
    op = operation

    auth_page_with_oauth do
      auth_card(r("common.sign_up").t, r(".description").t) do
        form_for SignUps::Create, class: "panel-body" do
          auth_form_fields do
            mount Shared::Field, attribute: op.email, label_text: r("fields.email").t, &.email_input(autofocus: "true", required: "", placeholder: "you@example.com")

            div class: "space-y-2" do
              div class: "grid gap-5 sm:grid-cols-2" do
                mount(
                  Shared::Field,
                  attribute: op.login_name,
                  label_text: r("fields.login_name").t
                ) do |field|
                  field.text_input(
                    required: "",
                    autocomplete: "username",
                    minlength: UserLoginName::MIN_LENGTH,
                    maxlength: UserLoginName::MAX_LENGTH,
                    placeholder: r(".login_name_placeholder").t
                  )
                end

                mount(
                  Shared::Field,
                  attribute: op.nickname,
                  label_text: r(".optional_nickname").t
                ) do |field|
                  field.text_input(placeholder: r(".nickname_placeholder").t)
                end
              end

              para r(".login_name_help").t, class: "m-0 text-xs leading-6 text-gray-500"
            end

            mount Shared::Field, attribute: op.password, label_text: r("fields.password").t, &.password_input(required: "", placeholder: r(".password_placeholder").t)
            mount Shared::Field, attribute: op.password_confirmation, label_text: r("fields.password_confirmation").t, &.password_input(required: "", placeholder: r(".confirmation_placeholder").t)

            div class: "form-field" do
              label r("fields.captcha_code").t, for: "captcha", class: "form-label"

              div class: "flex flex-wrap items-center gap-3" do
                input(
                  type: "text",
                  id: "captcha",
                  name: "captcha",
                  flow_id: "captcha",
                  required: "",
                  autocomplete: "off",
                  placeholder: r(".captcha_placeholder").t,
                  class: "form-input min-w-0 flex-1"
                )

                span(
                  id: "signup_captcha",
                  class: "inline-flex w-[11rem] shrink-0 cursor-pointer justify-center rounded-xl bg-sky-50 px-5 py-2.5 text-sm font-medium text-sky-700 transition hover:bg-sky-100",
                  hx_post: Htmx::SignUps::Captcha.path_without_query_params,
                  hx_target: "#signup_captcha",
                  hx_swap: "outerHTML"
                ) do
                  text r(".load_captcha").t
                end
              end

              mount Shared::FieldErrors, op.captcha_code
            end

            auth_form_actions do
              link r(".sign_in_instead").t, to: SignIns::New, class: "form-secondary"

              submit r("common.sign_up").t, type: "submit", flow_id: "sign-up-button", class: "form-submit"
            end
          end
        end
      end
    end
  end
end
