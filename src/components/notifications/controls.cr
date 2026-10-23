class Notifications::Controls < BaseComponent
  needs has_unread_notifications : Bool
  needs only_show_unread : Bool = false

  def render : Nil
    all_path = Notifications::Index.with(only_show_unread: false).path
    unread_path = Notifications::Index.with(only_show_unread: true).path

    div(
      id: "notifications-controls",
      "hx-target:inherited": "#notifications-content",
      "hx-swap:inherited": "innerHTML",
      "hx-push-url:inherited": "false",
      class: "order-last flex w-full items-center justify-between gap-2 sm:order-none sm:ml-auto sm:w-auto"
    ) do
      mount(
        Shared::Toggle,
        options: [{r(".all").t, all_path}, {r(".unread_only").t, unread_path}],
        selected: only_show_unread? ? unread_path : all_path
      )

      button(
        r(".read_all").t,
        id: "notifications-read-all",
        type: "button",
        attrs: has_unread_notifications? ? [] of Symbol : [:disabled],
        hx_post: Notifications::ReadAll.path,
        class: "form-secondary cursor-pointer rounded-md px-2.5 py-1.5 text-xs whitespace-nowrap shadow-none hover:shadow-none disabled:cursor-not-allowed disabled:opacity-50"
      )
    end
  end
end
