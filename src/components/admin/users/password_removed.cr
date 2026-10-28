class Admin::Users::PasswordRemoved < BaseComponent
  needs user : User
  needs password_changed_at : Time?
  needs flash : Lucky::FlashStore

  def render : Nil
    mount(
      Shared::UserPasswordStatus,
      user: user,
      password_changed_at: password_changed_at
    )

    tag(
      "hx-partial",
      hx_target: "#page-flash",
      hx_swap: "innerHTML"
    ) do
      mount Shared::FlashMessages, flash: flash
    end
  end
end
