class Shared::HtmxErrorAlert < BaseComponent
  def render
    div(
      id: "htmx-error-alert",
      role: "alert",
      hidden: true,
      "aria-live": "assertive",
      "aria-atomic": "true",
      class: "fixed top-4 right-4 z-[100] flex w-[calc(100%_-_2rem)] max-w-sm items-center gap-3 rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm font-medium text-rose-800 shadow-lg"
    ) do
      img src: asset("svgs/network-error.svg"), alt: "", hidden: true, data_htmx_error_icon: "", class: "h-10 w-10 shrink-0"
      span data_htmx_error_message: ""
    end
  end
end
