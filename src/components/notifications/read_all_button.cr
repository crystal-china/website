class Notifications::ReadAllButton < BaseComponent
  needs has_unread : Bool

  def render : Nil
    button(
      r("notifications.list.read_all").t,
      id: "notifications-read-all",
      type: "button",
      attrs: has_unread? ? [] of Symbol : [:disabled],
      hx_post: Notifications::ReadAll.path,
      hx_target: "#notifications-content",
      hx_swap: "innerHTML",
      class: "form-secondary cursor-pointer rounded-md px-2.5 py-1.5 text-xs whitespace-nowrap shadow-none hover:shadow-none disabled:cursor-not-allowed disabled:opacity-50"
    )
  end
end
