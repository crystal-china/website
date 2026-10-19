class OnlineUsers::Dialog < BaseComponent
  def render : Nil
    dialog(
      id: "online-users-dialog",
      "aria-labelledby": "online-users-title",
      class: "mx-auto mt-[8vh] max-h-[calc(100vh_-_2rem)] w-[calc(100%_-_2rem)] max-w-3xl rounded-xl border border-gray-300 bg-white p-0 shadow-xl sm:mt-[16vh]",
      script: <<-HYPER
#{dialog_outside_click("close me")}

on close
  focus the first <button/> in #online-users-status
end
HYPER
    ) do
      header class: "flex items-start justify-between gap-3 border-b border-gray-200 p-4" do
        div do
          h2(
            r(".title").t,
            id: "online-users-title",
            class: "m-0 text-base font-semibold text-gray-900"
          )
          para r(".description").t, class: "mt-1 mb-0 text-xs text-gray-500"
        end

        button(
          r("common.close").t,
          type: "button",
          class: "cursor-pointer text-sm text-gray-500 hover:text-gray-900",
          script: "on click close the closest <dialog/>"
        )
      end

      div(
        id: "online-users-content",
        class: "max-h-[60vh] overflow-y-auto",
        "aria-live": "polite"
      ) do
        para r(".loading").t, class: "m-0 p-4 text-center text-sm text-gray-500"
      end
    end
  end
end
