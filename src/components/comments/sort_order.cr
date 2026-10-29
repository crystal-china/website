@[Rosetta::Translatable::Config(prefix: "comments.toolbar")]
class Comments::SortOrder < BaseComponent
  needs url : String
  needs target_id : String
  needs order_by : String

  def render : Nil
    div class: "segmented-control" do
      [{r(".oldest").t, "asc"}, {r(".newest").t, "desc"}].each do |title, order|
        classes = order_by == order ? "segmented-option segmented-option-active" : "segmented-option"
        path = "#{url}&order_by=#{order}"

        a(
          title,
          class: classes,
          href: path,
          hx_get: path,
          hx_target: "##{target_id}",
          hx_swap: "outerHTML"
        )
      end
    end
  end
end
