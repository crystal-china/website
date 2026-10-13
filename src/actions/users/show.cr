class Users::Show < BrowserAction
  include Auth::AllowGuests

  get "/users/:login_name" do
    user = UserQuery.new.with_login_name(login_name).first

    html Users::ShowPage, user: user
  end
end
