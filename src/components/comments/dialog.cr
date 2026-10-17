class Comments::Dialog < BaseComponent
  private DIALOG_ID = "comment-dialog"
  private FORM_ID   = "comment-form"

  def self.comment_form_target : String
    "div##{FORM_ID}"
  end

  def self.open_comment_dialog : String
    <<-HYPER
on htmx:after:swap(ctx)[ctx.response.raw.ok]
  open ##{DIALOG_ID}
  focus the first <textarea/> in ##{DIALOG_ID}
end
HYPER
  end

  def render : Nil
    dialog(
      id: DIALOG_ID,
      class: "mx-auto mt-[8vh] max-h-[calc(100vh_-_2rem)] w-[calc(100%_-_2rem)] pb-0 sm:mt-[16vh] sm:w-[50em] sm:max-w-full",
      script: <<-HYPER
on closeRequested
  set textarea to the first <textarea/> in me
  if textarea and textarea.value is not textarea.defaultValue
    answer #{r("common.discard_changes").t.to_json} with true or false
    if the result
      close me
    end
  else
    close me
  end
end

-- 框外点击同样走未保存确认。
#{dialog_outside_click("send closeRequested to me")}

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
