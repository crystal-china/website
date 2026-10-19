class OnlineUsers::List < BaseComponent
  needs users : Array(User)

  def render : Nil
    if users.empty?
      para r(".empty").t, class: "m-0 p-6 text-center text-sm text-gray-500"
    else
      ul class: "m-0 grid grid-cols-1 list-none gap-x-3 gap-y-1 p-3 md:grid-cols-3" do
        users.each do |user|
          li do
            link(
              to: Users::Show.with(login_name: user.login_name),
              class: "flex min-w-0 items-center gap-2 rounded-md px-2 py-1.5 text-sm no-underline transition-colors hover:bg-sky-50 focus-visible:bg-sky-50"
            ) do
              mount(
                Shared::Avatar,
                user: user,
                classes: "h-6 w-6 rounded-full text-xs"
              )
              mount(
                Shared::UserName,
                user: user,
                linked: false
              )
            end
          end
        end
      end
    end
  end
end
