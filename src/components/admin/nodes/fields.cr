class Admin::Nodes::Fields < BaseComponent
  needs operation : SaveNode

  def render(&) : Nil
    div class: "grid gap-6 sm:grid-cols-2" do
      mount(
        Shared::Field,
        attribute: operation.name,
        label_text: r("fields.name").t,
        &.text_input(attrs: [:required], autofocus: "true")
      )
      mount(
        Shared::Field,
        attribute: operation.slug,
        label_text: r("fields.slug").t,
        &.text_input(attrs: [:required], placeholder: r(".slug_placeholder").t)
      )
    end

    mount(
      Shared::Field,
      attribute: operation.summary,
      label_text: r("fields.summary").t,
      &.textarea(attrs: [:required], rows: "4")
    )

    div class: "grid gap-6 sm:grid-cols-2" do
      mount(
        Shared::Field,
        attribute: operation.color,
        label_text: r("fields.color").t,
        &.color_input(attrs: [:required])
      )
      mount(
        Shared::Field,
        attribute: operation.position,
        label_text: r("fields.position").t,
        &.number_input(attrs: [:required], step: "1")
      )
    end

    div class: "flex flex-wrap items-center justify-end gap-3 border-t border-gray-200 pt-6" do
      yield
    end
  end
end
