class Notifications::Dialog < BaseComponent
  def render : Nil
    dialog(
      id: "notifications-dialog",
      "aria-labelledby": "notifications-title",
      # 打开、分页和标记已读共用请求队列，避免旧列表响应覆盖新状态。
      "hx-sync:inherited": "#notifications-dialog:replace",
      class: "mx-auto mt-[8vh] max-h-[calc(100vh_-_2rem)] w-[calc(100%_-_2rem)] max-w-2xl rounded-xl border border-gray-300 bg-white p-0 shadow-xl sm:mt-[16vh]",
      script: <<-HYPER
#{dialog_outside_click("close me")}

-- 列表刷新会替换铃铛按钮，关闭后将焦点交给当前按钮。
on close
  focus the first <button/> in #notification-status
end
HYPER
    ) do
      header class: "flex items-center justify-between gap-3 border-b border-gray-200 p-4" do
        h2 "通知", id: "notifications-title", class: "m-0 text-base font-semibold text-gray-900"
        button(
          "关闭",
          type: "button",
          class: "cursor-pointer text-sm text-gray-500 hover:text-gray-900",
          script: "on click close the closest <dialog/>"
        )
      end

      div(
        id: "notifications-content",
        class: "max-h-[60vh] overflow-y-auto",
        "aria-live": "polite"
      ) do
        para "正在读取通知...", class: "m-0 px-4 py-6 text-center text-sm text-gray-500"
      end
    end
  end
end
