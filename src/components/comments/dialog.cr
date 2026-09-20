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
      class: "mx-auto mt-[8vh] h-[40em] max-h-[calc(100vh_-_2rem)] w-[calc(100%_-_2rem)] pb-0 sm:mt-[16vh] sm:w-[50em] sm:max-w-full"
    ) do
      div id: FORM_ID do
      end
    end
  end
end
