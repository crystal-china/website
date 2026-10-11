class Navbar::UserMenu < BaseComponent
  def render
    user = current_user

    return if user.nil?

    # 原生 details 负责展开和键盘操作；只补上点击外部及 Esc 关闭。
    details(
      class: "nav-user-menu",
      script: <<-HYPER
on click from elsewhere
  remove @open from me
end

on keydown[event.key is "Escape"]
  halt the event
  remove @open from me
  focus the first <summary/> in me
end
HYPER
    ) do
      summary(
        class: "nav-user-trigger",
        title: "用户菜单",
        "aria-label": "#{user.name} 的用户菜单",
        "aria-controls": "nav-user-panel"
      ) do
        span class: "relative flex h-8 w-8 shrink-0 items-center justify-center overflow-hidden rounded-full bg-gray-800 text-sm font-semibold text-white ring-1 ring-black/5" do
          text user.name[0].to_s.upcase

          if (avatar = user.avatar.presence)
            img(
              src: avatar,
              alt: "",
              class: "absolute inset-0 h-8 w-8 rounded-full object-cover",
              onerror: "this.remove()"
            )
          end
        end

        span class: "nav-user-chevron", "aria-hidden": "true"
      end

      nav(
        id: "nav-user-panel",
        class: "nav-user-panel",
        "aria-label": "账户操作"
      ) do
        div class: "mb-1 border-b border-gray-100 px-3 pt-2 pb-3" do
          strong user.name, class: "block truncate text-sm font-semibold text-gray-900"
          span user.email, class: "mt-1 block truncate text-xs text-gray-500", title: user.email
        end

        link "个人设置", to: Me::Edit, class: menu_link_class(active: current_path == Me::Edit.path)

        if user.admin?
          link "管理后台", to: Admin::Index, class: menu_link_class(active: current_path.starts_with?("/admin"))
        end

        div class: "mt-1 border-t border-gray-100 pt-1" do
          link(
            "退出登录",
            to: SignIns::Delete,
            class: "nav-user-link nav-user-sign-out",
            flow_id: "sign-out-button",
            hx_delete: SignIns::Delete.path
          )
        end
      end
    end
  end

  private def menu_link_class(*, active : Bool = false)
    active ? "nav-user-link is-active" : "nav-user-link"
  end
end
