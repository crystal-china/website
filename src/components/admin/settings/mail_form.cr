@[Rosetta::Translatable::Config(prefix: "admin.settings.edit_page")]
class Admin::Settings::MailForm < BaseComponent
  needs operation : UpdateMailSettings
  needs flash : Lucky::FlashStore? = nil

  def render : Nil
    form_for(
      Admin::Settings::UpdateMail,
      id: "mail-settings-form",
      class: "panel-body space-y-7",
      hx_target: "#mail-settings-form",
      hx_swap: "outerHTML show:none",
      hx_push_url: "false"
    ) do
      render_mail_fields

      div class: "flex justify-end border-t border-gray-200 pt-5" do
        submit r("common.save_changes").t, class: "form-submit"
      end
    end

    if (flash = self.flash)
      tag(
        "hx-partial",
        hx_target: "#page-flash",
        hx_swap: "innerHTML show:none"
      ) do
        mount Shared::FlashMessages, flash: flash
      end
    end
  end

  private def render_mail_fields : Nil
    section class: "space-y-4" do
      para r(".mail_help").t, class: "m-0 text-sm text-gray-600"

      div class: "grid gap-4 pt-3 sm:grid-cols-2 lg:grid-cols-[8rem_minmax(0,1fr)_6rem_minmax(0,1fr)]" do
        div class: "form-field" do
          label_for(
            operation.smtp_tls_mode,
            r("fields.smtp_tls_mode").t,
            class: "form-label"
          )

          select_input(
            operation.smtp_tls_mode,
            attrs: [:required],
            class: "form-input"
          ) do
            options_for_select(
              operation.smtp_tls_mode,
              Space::SmtpTlsMode.values.map { |mode| {mode.to_s.upcase, mode} }
            )
          end

          mount Shared::FieldErrors, operation.smtp_tls_mode
        end

        mount(
          Shared::Field,
          attribute: operation.smtp_host,
          label_text: r("fields.smtp_host").t
        )
        mount(
          Shared::Field,
          attribute: operation.smtp_port,
          label_text: r("fields.smtp_port").t,
          &.number_input(min: "1", max: "65535")
        )
        mount(
          Shared::Field,
          attribute: operation.email_from,
          label_text: r("fields.email_from").t,
          &.email_input
        )
      end

      div class: "grid gap-4 sm:grid-cols-2" do
        mount(
          Shared::Field,
          attribute: operation.smtp_username,
          label_text: r("fields.smtp_username").t,
          &.text_input(autocomplete: "off")
        )

        div class: "form-field" do
          div class: "flex flex-wrap items-center justify-between gap-x-3 gap-y-2" do
            label_for(
              operation.smtp_password,
              r("fields.smtp_password").t,
              class: "form-label"
            )

            label_for(
              operation.clear_smtp_password,
              class: "inline-flex items-center gap-2 text-xs text-gray-500"
            ) do
              checkbox operation.clear_smtp_password, class: "h-4 w-4 accent-sky-600"
              text r(".clear_password").t
            end
          end

          password_placeholder = ""

          if (space = operation.record) && space.encrypted_smtp_password
            password_placeholder = r(".password_help").t
          end

          password_input(
            operation.smtp_password,
            class: "form-input",
            placeholder: password_placeholder,
            autocomplete: "new-password"
          )
          mount Shared::FieldErrors, operation.smtp_password
        end
      end
    end
  end
end
