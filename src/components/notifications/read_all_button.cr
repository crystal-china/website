class Notifications::Controls < BaseComponent
  needs has_unread : Bool
  needs unread : Bool = false

  def render : Nil
    div(
      id: "notifications-controls",
      class: "order-last flex w-full items-center justify-between gap-2 sm:order-none sm:ml-auto sm:w-auto"
    ) do
      div class: "segmented-control" do
        [{r(".all").t, false}, {r(".unread_only").t, true}].each do |label, only_unread|
          path = only_unread ? Notifications::Index.with(unread: true).path : Notifications::Index.path
          classes = unread? == only_unread ? "segmented-option segmented-option-active" : "segmented-option"

          a(
            label,
            href: path,
            hx_get: path,
            hx_target: "#notifications-content",
            hx_swap: "innerHTML",
            hx_push_url: "false",
            class: "#{classes} px-2 py-1 text-xs"
          )
        end
      end

      button(
        r(".read_all").t,
        id: "notifications-read-all",
        type: "button",
        attrs: has_unread? ? [] of Symbol : [:disabled],
        hx_post: unread? ? Notifications::ReadAll.with(unread: true).path : Notifications::ReadAll.path,
        hx_target: "#notifications-content",
        hx_swap: "innerHTML",
        class: "form-secondary cursor-pointer rounded-md px-2.5 py-1.5 text-xs whitespace-nowrap shadow-none hover:shadow-none disabled:cursor-not-allowed disabled:opacity-50"
      )
    end
  end
end
