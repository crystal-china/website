class Shared::FlashMessages < BaseComponent
  needs flash : Lucky::FlashStore

  def render
    flash.each do |flash_type, flash_message|
      flash_class = case flash_type
                    when "failure"
                      "flash-message--failure"
                    when "info"
                      "flash-message--info"
                    else
                      "flash-message--success"
                    end

      div class: "flash-message #{flash_class}", flow_id: "flash" do
        text flash_message
      end
    end
  end
end
