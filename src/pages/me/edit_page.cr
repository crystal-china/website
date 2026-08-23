class Me::EditPage < MainLayout
  needs op : UpdateUser

  def page_title
    "编辑我的信息"
  end

  def content
    div class: "#{page_container_classes} py-10" do
      section class: "mx-auto w-full max-w-3xl overflow-hidden rounded-3xl border border-gray-200 bg-white shadow-sm" do
        header class: "border-b border-gray-200 bg-gradient-to-r from-sky-50 via-white to-cyan-50 px-8 py-7" do
          h1 "编辑我的信息", class: "text-3xl font-semibold tracking-tight text-gray-900"
          para "更新昵称、头像和登录密码。头像目前仅支持 http/https 图片链接。", class: "mt-2 text-sm leading-6 text-gray-600"
        end

        form_for Me::Update, class: "space-y-8 px-8 py-8" do
          div class: "grid gap-8 md:grid-cols-[minmax(0,1fr)_15rem]" do
            div class: "space-y-6" do
              mount Shared::Field, attribute: op.name, label_text: "昵称", &.text_input(placeholder: "输入你希望显示的名字")

              mount Shared::Field, attribute: op.avatar, label_text: "头像链接", &.text_input(placeholder: "https://example.com/avatar.png", autofocus: true)

              div class: "grid gap-6 md:grid-cols-2" do
                mount Shared::Field, attribute: op.password, label_text: "密码", &.password_input(placeholder: "留空则不修改")

                mount Shared::Field, attribute: op.password_confirmation, label_text: "确认密码", &.password_input(placeholder: "再次输入新密码")
              end
            end

            render_avatar_preview
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

      para class: "mt-4 text-sm leading-6 text-gray-600" do
        text avatar ? "当前将使用上面的图片作为头像。" : "未设置头像时，会显示默认首字母占位图。"
      end
    end
  end
end
