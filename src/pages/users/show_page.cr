class Users::ShowPage < MainLayout
  needs user : User

  def page_title : String
    "#{user.nickname} (@#{user.login_name})"
  end

  def page_description : String
    "#{user.nickname} 在 Crystal 中文社区的个人主页。"
  end

  def content : Nil
    div class: "#{page_container_classes} py-10 sm:py-16" do
      article class: "app-panel mx-auto max-w-2xl overflow-hidden" do
        div class: "h-24 border-b border-sky-100 bg-gradient-to-r from-sky-100 via-slate-100 to-amber-50 sm:h-32", "aria-hidden": "true"

        div class: "px-6 pb-8 sm:px-10" do
          div class: "relative -mt-10 flex h-20 w-20 items-center justify-center overflow-hidden rounded-2xl bg-slate-800 text-3xl font-semibold text-white ring-4 ring-white" do
            text user.nickname[0].to_s.upcase

            if (avatar = user.avatar.presence)
              img src: avatar, alt: "", class: "absolute inset-0 h-full w-full object-cover", onerror: "this.remove()"
            end
          end

          header class: "mt-5 flex flex-wrap items-start justify-between gap-4" do
            div class: "min-w-0" do
              h1 user.nickname, class: "m-0 break-words text-2xl font-semibold tracking-tight text-gray-900"
              para "@#{user.login_name}", class: "mt-1 mb-0 break-all text-sm text-gray-500"
            end

            if current_user.try(&.id) == user.id
              link "编辑个人资料", to: Me::Edit, class: "form-secondary"
            end
          end

          dl class: "mt-8 border-t border-gray-100 pt-5 text-sm" do
            dt "加入社区", class: "text-gray-500"
            dd user.created_at.to_local.to_s("%Y-%m-%d"), class: "mt-1 ml-0 font-medium text-gray-800"
          end
        end
      end
    end
  end
end
