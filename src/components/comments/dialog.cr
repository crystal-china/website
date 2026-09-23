class Comments::Dialog < BaseComponent
  private DIALOG_ID = "comment-dialog"
  private FORM_ID   = "comment-form"

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
      class: "mx-auto mt-[8vh] h-[40em] max-h-[calc(100vh_-_2rem)] w-[calc(100%_-_2rem)] pb-0 sm:mt-[16vh] sm:w-[50em] sm:max-w-full",
      script: <<-HYPER
on closeRequested
  set textarea to the first <textarea/> in me
  if textarea and textarea.value is not textarea.defaultValue
    answer "内容尚未保存，确定放弃修改吗？" with true or false
    if the result
      close me
    end
  else
    close me
  end
end

on keydown[event.key is "Escape"]
  halt the event
  send closeRequested to me
end
HYPER
    ) do
      div id: FORM_ID do
      end
    end
  end
end
