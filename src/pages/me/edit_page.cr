class Me::EditPage < MainLayout
  needs op : UpdateUser

  def page_title
    "编辑我的信息"
  end

  def content
    div class: "#{page_container_classes} py-10" do
      section class: "app-panel mx-auto w-full max-w-3xl overflow-hidden" do
        header class: "panel-header" do
          h1 "编辑我的信息", class: "panel-title"
          para "更新昵称、头像和登录密码。头像目前仅支持 http/https 图片链接。", class: "panel-description"
        end

        form_for Me::Update, class: "panel-body space-y-8" do
          div class: "grid gap-8 md:grid-cols-[minmax(0,1fr)_15rem]" do
            div class: "space-y-6" do
              div class: "space-y-2" do
                mount Shared::Field, attribute: op.login_name, label_text: "登录用户名", &.text_input(placeholder: "用于 @提及", minlength: UserLoginName::MIN_LENGTH, maxlength: UserLoginName::MAX_LENGTH)
                para "长度为 2–20 个字符，以英文字母、数字或 _ 开头，以字母或数字结尾；中间允许 _、-、.，但符号不能相邻，不区分大小写唯一。", class: "m-0 text-xs leading-6 text-gray-500"
              end

              mount Shared::Field, attribute: op.nickname, label_text: "昵称", &.text_input(placeholder: "留空使用用户名")

              mount Shared::Field, attribute: op.avatar, label_text: "头像链接", &.text_input(placeholder: "https://example.com/avatar.png", autofocus: true)

              div class: "grid gap-6 md:grid-cols-2" do
                mount Shared::Field, attribute: op.password, label_text: "密码", &.password_input(placeholder: "留空则不修改")

                mount Shared::Field, attribute: op.password_confirmation, label_text: "确认密码", &.password_input(placeholder: "再次输入新密码")
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
            a(
              "返回",
              href: previous_url(fallback: Home::Index),
              class: "form-secondary"
            )

            submit(
              "保存修改",
              class: "form-submit"
            )
          end
        end
      end
    end
  end

  private def render_avatar_preview
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
            text current_user.try(&.email[0].to_s.upcase) || "U"
          end
        end
      end

      para class: "mt-4 mb-0 text-sm leading-6 text-gray-600" do
        text avatar ? "当前将使用上面的图片作为头像。" : "未设置头像时，会显示默认首字母占位图。"
      end
    end
  end
end
