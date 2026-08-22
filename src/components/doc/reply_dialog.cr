class Docs::ReplyDialog < BaseComponent
  private DIALOG_ID = "edit_dialog"
  private FORM_ID   = "reply_to_reply-form"

  def self.reply_form_target
    "div##{FORM_ID}"
  end

  def self.open_reply_dialog_js
    <<-JS
const dialog = document.getElementById('#{DIALOG_ID}');
dialog?.showModal();
dialog?.querySelector('textarea')?.focus();
JS
  end

  def render
    dialog(
      id: DIALOG_ID,
      class: "mx-auto mt-[16vh] h-[40em] max-h-full w-[50em] max-w-full pb-0"
    ) do
      div id: FORM_ID do
      end
    end
  end
end
