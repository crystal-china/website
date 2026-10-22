class Shared::Toggle < BaseComponent
  needs options : Array(Tuple(String, String))
  needs selected : String

  def render : Nil
    div class: "segmented-control" do
      options.each do |label, url|
        classes = selected == url ? "segmented-option segmented-option-active" : "segmented-option"

        a(
          label,
          href: url,
          class: "#{classes} px-2 py-1 text-xs"
        )
      end
    end
  end
end
