class Comments::Dialog < BaseComponent
  private DIALOG_ID         = "comment-dialog"
  private DISCARD_DIALOG_ID = "discard-comment-dialog"
  private FORM_ID           = "comment-form"

  def self.comment_form_target
    "div##{FORM_ID}"
  end

  def self.open_comment_dialog
    <<-HYPER
on htmx:after:swap(ctx)[ctx.response.raw.ok]
  open ##{DIALOG_ID}
  focus the first <textarea/> in ##{DIALOG_ID}
end
HYPER
  end

  def render
    dialog(
      id: DIALOG_ID,
      class: "relative mx-auto mt-[8vh] h-[40em] max-h-[calc(100vh_-_2rem)] w-[calc(100%_-_2rem)] pb-0 sm:mt-[16vh] sm:w-[50em] sm:max-w-full",
      script: <<-HYPER
on every closeRequested
  set textarea to the first <textarea/> in me
  if textarea and textarea.value is not textarea.defaultValue
    remove @hidden from ##{DISCARD_DIALOG_ID}
    focus the first <button/> in ##{DISCARD_DIALOG_ID}
  else
    close me
  end

on every keydown[event.key is "Escape"]
  halt the event
  if ##{DISCARD_DIALOG_ID}.hidden
    send closeRequested to me
  else
    add @hidden to ##{DISCARD_DIALOG_ID}
    focus the first <textarea/> in me
  end
end
HYPER
    ) do
      div id: FORM_ID do
      end

      div(
        id: DISCARD_DIALOG_ID,
        hidden: "",
        role: "alertdialog",
        class: "absolute inset-0 z-10 flex items-center justify-center bg-black/30 p-4",
        "aria-labelledby": "discard-comment-title"
      ) do
        section class: "w-full max-w-md rounded-2xl border border-gray-200 bg-white p-6 text-gray-900" do
          h2 "放弃修改？", id: "discard-comment-title", class: "text-lg font-semibold"
          para "内容尚未保存，确定放弃修改吗？", class: "mt-2 text-sm text-gray-600"

          div class: "mt-6 flex justify-end gap-3" do
            button(
              "继续编辑",
              type: "button",
              class: "rounded-xl border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 transition hover:border-gray-400 hover:bg-gray-50",
              script: "on click add @hidden to ##{DISCARD_DIALOG_ID} then focus the first <textarea/> in ##{DIALOG_ID}"
            )
            button(
              "放弃修改",
              type: "button",
              class: "rounded-xl bg-red-600 px-4 py-2 text-sm font-semibold text-white transition hover:bg-red-700",
              script: "on click add @hidden to ##{DISCARD_DIALOG_ID} then close ##{DIALOG_ID}"
            )
          end
        end
      end
    end
  end
end
