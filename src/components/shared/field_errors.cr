class Shared::FieldErrors(T) < BaseComponent
  needs attribute : Avram::PermittedAttribute(T)

  # Customize the markup and styles to match your application
  def render : Nil
    unless attribute.valid?
      div class: "error" do
        text ValidationErrors.format(attribute.name, attribute.errors.first)
      end
    end
  end
end
