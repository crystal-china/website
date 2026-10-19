class Navbar::UserMenu < BaseComponent
  def render : Nil
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
        title: r(".user_menu").t,
        "aria-label": r(".named_user_menu").t(nickname: user.nickname),
        "aria-controls": "nav-user-panel"
      ) do
        mount(
          Shared::Avatar,
          user: user,
          classes: "h-8 w-8 rounded-full text-sm ring-1 ring-black/5"
        )

        span class: "nav-user-chevron", "aria-hidden": "true"
      end

      nav(
        id: "nav-user-panel",
        class: "nav-user-panel",
        "aria-label": r(".account_actions").t
      ) do
        div class: "nav-user-identity" do
          mount(
            Shared::Avatar,
            user: user,
            classes: "h-11 w-11 rounded-xl text-base"
          )

          div class: "min-w-0 text-sm" do
            mount(
              Shared::UserName,
              user: user,
              stacked: true
            )
          end
        end

        link(
          r("common.profile").t,
          to: Users::Show.with(login_name: user.login_name),
          class: menu_link_class
        )

        if user.admin?
          link(
            r(".admin").t,
            to: Admin::Index,
            class: menu_link_class(active: current_path.starts_with?("/admin"))
          )
        end

        div class: "mt-1 border-t border-gray-100 pt-1" do
          link(
            r("common.sign_out").t,
            to: SignIns::Delete,
            class: "nav-user-link nav-user-sign-out",
            flow_id: "sign-out-button",
            hx_delete: SignIns::Delete.path
          )
        end
      end
    end
  end

  private def menu_link_class(*, active : Bool = false) : String
    active ? "nav-user-link is-active" : "nav-user-link"
  end
end
