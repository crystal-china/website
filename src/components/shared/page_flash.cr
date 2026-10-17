class Shared::PageFlash < BaseComponent
  needs flash : Lucky::FlashStore

  def render : Nil
    div(
      id: "page-flash",
      role: "status",
      "aria-atomic": "true",
      class: "fixed top-4 right-4 z-[90] flex w-[calc(100%_-_2rem)] max-w-[300px] flex-col gap-3"
    ) do
      mount Shared::FlashMessages, flash
    end
  end
end
