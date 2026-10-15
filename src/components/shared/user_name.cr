class Shared::UserName < BaseComponent
  needs user : User
  needs linked : Bool = true
  needs stacked : Bool = false

  def render : Nil
    classes = stacked? ? "user-name user-name-stacked" : "user-name"

    if linked?
      link(to: Users::Show.with(login_name: user.login_name), class: classes) do
        render_names
      end
    else
      span(class: classes) do
        render_names
      end
    end
  end

  private def render_names : Nil
    span user.nickname, class: "user-name-nickname"
    text " "
    span "@#{user.login_name}", class: "user-name-login"
  end
end
