class Shared::FlashMessages < BaseComponent
  needs flash : Lucky::FlashStore

  def render : Nil
    dismiss_flash_message_on_click_or_after_timeout_script = <<-HYPER
init
  wait 15s
  remove me
end

on click remove me
HYPER

    flash.each do |flash_type, flash_message|
      flash_class = case flash_type
                    when "failure"
                      "flash-message--failure"
                    when "info"
                      "flash-message--info"
                    else
                      "flash-message--success"
                    end

      div(
        class: "flash-message #{flash_class} cursor-pointer",
        flow_id: "flash",
        script: dismiss_flash_message_on_click_or_after_timeout_script
      ) do
        text flash_message
      end
    end
  end
end
