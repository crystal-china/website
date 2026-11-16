@[Rosetta::Translatable::Config(prefix: "admin.settings.edit_page")]
class Admin::Settings::SiteForm < BaseComponent
  needs operation : UpdateSpaceSettings
  needs flash : Lucky::FlashStore? = nil

  def render : Nil
    form_for(
      Admin::Settings::Update,
      id: "site-settings-form",
      class: "panel-body space-y-7",
      hx_target: "#site-settings-form",
      hx_swap: "outerHTML show:none",
      hx_push_url: "false"
    ) do
      render_branding_fields
      render_footer_link_fields

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

  private def render_branding_fields : Nil
    section class: "space-y-4" do
      para r(".defaults_help").t, class: "m-0 text-sm text-gray-600"

      div class: "grid gap-4 pt-3 sm:grid-cols-2" do
        mount(
          Shared::Field,
          attribute: operation.logo_url,
          label_text: r("fields.logo_url").t,
          &.text_input(value: operation.logo_url.value || Space::DEFAULT_LOGO_PATH)
        )
        mount(
          Shared::Field,
          attribute: operation.contact_email,
          label_text: r("fields.contact_email").t,
          &.email_input(value: operation.contact_email.value || Space::DEFAULT_CONTACT_EMAIL)
        )
        mount(
          Shared::Field,
          attribute: operation.source_url,
          label_text: r("fields.source_url").t,
          &.url_input(value: operation.source_url.value || Space::DEFAULT_SOURCE_URL)
        )
      end
    end
  end

  private def render_footer_link_fields : Nil
    append_empty_footer_link_row_script = <<-HYPER
on click
  set nextIndex to #footer-link-rows.dataset.nextIndex as Int
  set rowHtml to #footer-link-template.innerHTML.replaceAll('__INDEX__', nextIndex)
  set #footer-link-rows.dataset.nextIndex to nextIndex + 1
  put rowHtml at end of #footer-link-rows
end
HYPER

    section class: "space-y-4 border-t border-gray-200 pt-5" do
      h2 r("fields.footer_links").t, class: "m-0 text-base font-semibold"

      # 即使删除全部链接行，也提交 footer_links，保存为 []；未提交时保留原值。
      input(
        type: "hidden",
        name: "footer_links",
        value: ""
      )

      unless operation.footer_links.valid?
        para operation.footer_links.errors.first, class: "error"
      end

      fieldset(
        id: "footer-link-fields",
        class: "min-w-0 space-y-4 border-0 p-0"
      ) do
        para r(".links_help").t, class: "m-0 text-sm text-gray-600"

        rows = operation.footer_link_rows
        rows = [Space::FooterLink.new] if rows.empty?

        div(
          id: "footer-link-rows",
          class: "space-y-3",
          data_next_index: rows.size.to_s
        ) do
          rows.each_with_index do |link, index|
            mount(
              Admin::Settings::FooterLinkFields,
              link: link,
              index: index.to_s
            )
          end
        end

        tag("template", id: "footer-link-template") do
          mount Admin::Settings::FooterLinkFields, index: "__INDEX__"
        end

        button(
          r(".add_link").t,
          type: "button",
          class: "form-secondary",
          script: append_empty_footer_link_row_script
        )
      end
    end
  end
end
