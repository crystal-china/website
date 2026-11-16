class Admin::Settings::FooterLinkFields < BaseComponent
  needs link : Space::FooterLink = Space::FooterLink.new
  needs index : String

  def render : Nil
    remove_footer_link_row_script = "on click remove the closest .footer-link-row"

    div class: "footer-link-row grid gap-3 rounded-lg border border-gray-200 p-4 sm:grid-cols-[1fr_2fr_2fr_auto] sm:items-end" do
      label class: "form-field" do
        span r(".title").t, class: "form-label"
        input(
          type: "text",
          name: "footer_links[#{index}]:title",
          value: link.title,
          class: "form-input"
        )
      end

      label class: "form-field" do
        span r(".url").t, class: "form-label"
        input(
          type: "url",
          name: "footer_links[#{index}]:url",
          value: link.url,
          class: "form-input"
        )
      end

      label class: "form-field" do
        span r(".icon").t, class: "form-label"
        input(
          type: "text",
          name: "footer_links[#{index}]:icon",
          value: link.icon,
          class: "form-input"
        )
      end

      button(
        r("common.delete").t,
        type: "button",
        class: "form-secondary text-red-700",
        script: remove_footer_link_row_script
      )
    end
  end
end
