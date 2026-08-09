class Htmx::Null < BrowserAction
  include Auth::AllowGuests

  get "/htmx/null" do
    head 200
  end
end
