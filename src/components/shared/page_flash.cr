class Shared::PageFlash < BaseComponent
  needs flash : Lucky::FlashStore

  def render
    div class: "mx-auto flex w-full max-w-7xl justify-end px-8 pt-2" do
      mount Shared::FlashMessages, flash
    end
  end
end
