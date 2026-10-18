class Shared::UserProfileForm < BaseComponent
  needs user : User
  needs op : UpdateUser
  needs return_path : String
  needs password_changed_at : Time?

  def render : Nil
    login_name_editable = user.login_name_change_allowed? || current_user.not_nil!.admin?

    section class: "app-panel mx-auto w-full max-w-3xl overflow-hidden" do
      header class: "panel-header flex flex-wrap items-center justify-between gap-4" do
        div do
          h1 r("common.edit_profile").t, class: "panel-title"
          para r(".description").t, class: "panel-description"
        end

        link r("common.back_to_profile").t, to: Users::Show.with(login_name: user.login_name), class: "form-secondary"
      end

      form_for(Users::Update.with(id: user.id), class: "panel-body space-y-8") do
        input type: "hidden", name: "return_to", value: return_path

        div class: "grid gap-8 md:grid-cols-[minmax(0,1fr)_15rem]" do
          div class: "space-y-6" do
            div class: "space-y-2" do
              mount Shared::Field, attribute: op.login_name, label_text: r("fields.login_name").t do |field|
                field.text_input(
                  placeholder: r(".login_name_placeholder").t,
                  minlength: UserLoginName::MIN_LENGTH,
                  maxlength: UserLoginName::MAX_LENGTH,
                  attrs: login_name_editable ? [] of Symbol : [:readonly],
                  "aria-describedby": "login-name-help"
                )
              end
              para r(".login_name_help").t, id: "login-name-help", class: "m-0 text-xs leading-6 text-gray-500"
            end

            mount Shared::Field, attribute: op.nickname, label_text: r("fields.nickname").t, &.text_input(placeholder: r(".nickname_placeholder").t)
            mount Shared::Field, attribute: op.tagline, label_text: r("fields.tagline").t, &.text_input(placeholder: r(".tagline_placeholder").t, maxlength: User::Profile::MAX_TAGLINE_LENGTH)
            mount Shared::Field, attribute: op.bio, label_text: r("fields.bio").t, &.textarea(rows: 5, maxlength: User::Profile::MAX_BIO_LENGTH)
            mount Shared::Field, attribute: op.avatar, label_text: r("fields.avatar_url").t, &.text_input(placeholder: "https://example.com/avatar.png", autofocus: true)

            div class: "grid gap-6 md:grid-cols-2" do
              div class: "form-field" do
                label_for op.password, r("fields.password").t, class: "form-label"

                password_input op.password, class: "form-input", placeholder: r(".password_placeholder").t, autocomplete: "new-password"
                mount Shared::FieldErrors, op.password
              end

              mount Shared::Field, attribute: op.password_confirmation, label_text: r("fields.password_confirmation").t, &.password_input(placeholder: r(".confirmation_placeholder").t, autocomplete: "new-password")
            end

            para class: "m-0 text-xs text-gray-500" do
              if (changed_at = password_changed_at)
                text r(".last_password_change").t
                local_time(
                  changed_at,
                  relative_time(changed_at)
                )
              else
                text r(".unknown_password_date").t
              end

              if current_user.not_nil!.admin? && user.encrypted_password
                button(
                  r(".remove_password").t,
                  type: "button",
                  class: "ml-3 text-xs whitespace-nowrap text-red-700 hover:underline",
                  hx_delete: Admin::Users::RemovePassword.with(id: user.id).path,
                  hx_target: "#page-flash",
                  hx_swap: "innerHTML",
                  hx_confirm: r(".confirm_remove_password").t,
                  hx_disable: "this",
                  script: htmx_success("remove me")
                )
              end
            end
          end

          render_avatar_preview
        end

        div class: "space-y-2 border-t border-gray-200 pt-6" do
          label_for op.mention_notifications_enabled, class: "flex cursor-pointer items-center gap-3 text-sm font-medium text-gray-800" do
            checkbox op.mention_notifications_enabled, class: "h-4 w-4 rounded border-gray-300 accent-sky-600", "aria-describedby": "mention-notifications-help"
            text r(".mention_notifications").t
          end
          para r(".mention_notifications_help").t, id: "mention-notifications-help", class: "m-0 text-sm leading-6 text-gray-500"
          mount Shared::FieldErrors, op.mention_notifications_enabled
        end

        div class: "flex flex-wrap items-center justify-end gap-3 border-t border-gray-200 pt-6" do
          a r("common.back").t, href: return_path, class: "form-secondary"
          submit r("common.save_changes").t, class: "form-submit"
        end
      end
    end
  end

  private def render_avatar_preview : Nil
    avatar = op.avatar.value

    figure class: "flex h-full flex-col rounded-2xl border border-gray-200 bg-gray-50/80 p-5" do
      figcaption class: "text-sm font-medium text-gray-800" do
        text r(".avatar_preview").t
      end

      div class: "mt-4 flex flex-1 items-center justify-center rounded-2xl border border-dashed border-gray-300 bg-white p-5" do
        if avatar
          img src: avatar, alt: r(".current_avatar").t, class: "h-36 w-36 rounded-2xl object-cover shadow-sm"
        else
          div class: "flex h-36 w-36 items-center justify-center rounded-2xl bg-gray-900 text-4xl font-semibold text-white" do
            text user.nickname[0].to_s.upcase
          end
        end
      end

      para class: "mt-4 mb-0 text-sm leading-6 text-gray-600" do
        text avatar ? r(".avatar_help").t : r(".no_avatar").t
      end
    end
  end
end
