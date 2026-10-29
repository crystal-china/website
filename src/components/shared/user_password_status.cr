@[Rosetta::Translatable::Config(prefix: "shared.user_profile_form")]
class Shared::UserPasswordStatus < BaseComponent
  needs user : User
  needs password_changed_at : Time?

  def render : Nil
    para(
      id: "user-password-status",
      class: "m-0 text-xs text-gray-500"
    ) do
      if (changed_at = password_changed_at)
        text r(".last_password_change").t
        local_time(
          changed_at,
          relative_time(changed_at)
        )
      else
        text r(".no_password_record").t
      end

      if current_user.not_nil!.admin? && user.encrypted_password
        button(
          r(".remove_password").t,
          type: "button",
          class: "ml-3 text-xs whitespace-nowrap text-red-700 hover:underline",
          hx_delete: Admin::Users::RemovePassword.with(id: user.id).path,
          hx_target: "#user-password-status",
          hx_swap: "outerHTML",
          hx_confirm: r(".confirm_remove_password").t,
          hx_disable: "this"
        )
      end
    end
  end
end
