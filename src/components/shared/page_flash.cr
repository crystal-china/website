class Shared::PageFlash < BaseComponent
  needs flash : Lucky::FlashStore

  def render
    div class: "mx-auto flex w-full max-w-7xl justify-end px-4 pt-2 sm:px-6 lg:px-8" do
      mount Shared::FlashMessages, flash
    end
  end
end
