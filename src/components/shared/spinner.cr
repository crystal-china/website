class Shared::Spinner < BaseComponent
  needs text : String
  needs width : String?

  def render
    div class: "flex flex-col items-center" do
      opts = {
        class: "htmx-indicator",
        src:   asset("svgs/spinning-circles.svg"),
        alt:   text,
      }

      if width
        opts = opts.merge(style: "width: #{width};")
      end

      img(opts)
    end
  end
end
