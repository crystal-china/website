class Shared::UserProfileForm < BaseComponent
  needs user : User
  needs op : UpdateUser
  needs update_route : Lucky::RouteHelper
  needs password_changed_at : Time?

  def render : Nil
    section class: "app-panel mx-auto w-full max-w-3xl overflow-hidden" do
      header class: "panel-header flex flex-wrap items-center justify-between gap-4" do
        div do
          h1 "编辑个人资料", class: "panel-title"
          para "更新昵称、头像和登录密码。头像目前仅支持 http/https 图片链接。", class: "panel-description"
        end

        link "回到主页", to: Users::Show.with(login_name: user.login_name), class: "form-secondary"
      end

      form_for(update_route, class: "panel-body space-y-8") do
        div class: "grid gap-8 md:grid-cols-[minmax(0,1fr)_15rem]" do
          div class: "space-y-6" do
            div class: "space-y-2" do
              mount Shared::Field, attribute: op.login_name, label_text: "登录用户名" do |field|
                field.text_input(
                  placeholder: "用于 @提及",
                  minlength: UserLoginName::MIN_LENGTH,
                  maxlength: UserLoginName::MAX_LENGTH,
                  attrs: user.login_name_change_allowed? || current_user.not_nil!.admin? ? [] of Symbol : [:readonly]
                )
              end
              para "长度为 2–20 个字符，以英文字母、数字或 _ 开头，以字母或数字结尾；中间允许 _、-、.，但符号不能相邻，不区分大小写唯一。", class: "m-0 text-xs leading-6 text-gray-500"
              if current_user.not_nil!.admin?
                para "管理员可修改登录用户名，不受注册后 7 天的期限限制。", class: "m-0 text-xs leading-6 text-gray-500"
              else
                para "仅能在注册后 7 天内修改登录用户名，之后固定；昵称不受此限制。", class: "m-0 text-xs leading-6 text-gray-500"
              end
            end

            mount Shared::Field, attribute: op.nickname, label_text: "昵称", &.text_input(placeholder: "留空使用用户名")
            mount Shared::Field, attribute: op.avatar, label_text: "头像链接", &.text_input(placeholder: "https://example.com/avatar.png", autofocus: true)

            div class: "grid gap-6 md:grid-cols-2" do
              div class: "form-field" do
                div class: "flex items-center justify-between gap-3" do
                  label_for op.password, "密码", class: "form-label"

                  if current_user.not_nil!.admin? && user.encrypted_password
                    button "移除密码", type: "submit", form: "remove-user-password", class: "text-xs text-red-700 hover:underline"
                  end
                end

                password_input op.password, class: "form-input", placeholder: "留空则不修改", autocomplete: "new-password"
                mount Shared::FieldErrors, op.password
              end

              mount Shared::Field, attribute: op.password_confirmation, label_text: "确认密码", &.password_input(placeholder: "再次输入新密码", autocomplete: "new-password")
            end

            para class: "m-0 text-xs text-gray-500" do
              if (changed_at = password_changed_at)
                text "上次修改密码："
                time(
                  TimeInWords::Helpers(TimeInWords::I18n::ZH_CN).from(past_time: changed_at),
                  datetime: changed_at.to_rfc3339,
                  title: changed_at.to_local.to_s("%Y-%m-%d %H:%M:%S %z")
                )
              else
                text "暂无密码修改记录；启用账户记录之前的修改时间未知。"
              end
            end
          end

          render_avatar_preview
        end

        div class: "space-y-2 border-t border-gray-200 pt-6" do
          label_for op.mention_notifications_enabled, class: "flex cursor-pointer items-center gap-3 text-sm font-medium text-gray-800" do
            checkbox op.mention_notifications_enabled, class: "h-4 w-4 rounded border-gray-300 accent-sky-600", "aria-describedby": "mention-notifications-help"
            text "接收 @提及通知"
          end
          para "关闭后，不接收任何人的 @提及通知；正常回复和管理通知不受影响，已有通知仍保留。", id: "mention-notifications-help", class: "m-0 text-sm leading-6 text-gray-500"
          mount Shared::FieldErrors, op.mention_notifications_enabled
        end

        div class: "flex flex-wrap items-center justify-end gap-3 border-t border-gray-200 pt-6" do
          link "返回", to: Users::Show.with(login_name: user.login_name), class: "form-secondary"
          submit "保存修改", class: "form-submit"
        end
      end

      if current_user.not_nil!.admin? && user.encrypted_password
        # 独立表单避免嵌套；密码旁的按钮通过 form 属性提交，且不提交未保存的资料。
        form_for(
          Admin::Users::RemovePassword.with(id: user.id),
          id: "remove-user-password",
          hx_confirm: "确定移除本站密码？旧登录会话将失效，之后需通过第三方登录或重置密码登录。"
        ) do
        end
      end
    end
  end

  private def render_avatar_preview : Nil
    avatar = op.avatar.value

    figure class: "flex h-full flex-col rounded-2xl border border-gray-200 bg-gray-50/80 p-5" do
      figcaption class: "text-sm font-medium text-gray-800" do
        text "头像预览"
      end

      div class: "mt-4 flex flex-1 items-center justify-center rounded-2xl border border-dashed border-gray-300 bg-white p-5" do
        if avatar
          img src: avatar, alt: "当前头像", class: "h-36 w-36 rounded-2xl object-cover shadow-sm"
        else
          div class: "flex h-36 w-36 items-center justify-center rounded-2xl bg-gray-900 text-4xl font-semibold text-white" do
            text user.nickname[0].to_s.upcase
          end
        end
      end

      para class: "mt-4 mb-0 text-sm leading-6 text-gray-600" do
        text avatar ? "当前将使用上面的图片作为头像。" : "未设置头像时，会显示默认首字母占位图。"
      end
    end
  end
end
