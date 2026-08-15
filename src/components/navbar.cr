class Navbar < BaseComponent
  def render
    header class: "sticky top-0 z-50" do
      div class: "flex items-center justify-between border-b border-black bg-[#F2F4F6] pb-4 #{page_container_classes}" do
        a href: "/", class: "inline-flex shrink-0 items-center" do
          img src: asset("svgs/crystal.svg"), alt: "crystal-china", class: "w-[180px]"
          span "China", class: "ml-6 text-lg font-semibold tracking-wide text-black uppercase"
        end

        nav class: "flex flex-1 justify-end" do
          ul class: "m-0 flex list-none flex-wrap items-center justify-end gap-x-6 p-0" do
            li do
              if current_path.starts_with?("/docs")
                tag "search" do
                  button(
                    "搜索文档",
                    class: nav_item_class(active: true),
                    onclick: "document.getElementById('doc_search_dialog').showModal();",
                    flow_id: "doc_index"
                  )
                end
              else
                a "学习文档", href: "/docs/index", flow_id: "doc_index", class: nav_item_class
              end
            end

            li do
              a "本站源码", href: "https://github.com/crystal-china/website", class: nav_item_class
            end

            me = current_user
            if me
              li do
                link(
                  "登出",
                  class: nav_item_class,
                  to: SignIns::Delete,
                  flow_id: "sign-out-button",
                  hx_target: "body",
                  hx_push_url: "true",
                  hx_delete: SignIns::Delete.path,
                  hx_include: "[name='_csrf']",
                )
              end

              li { link me.email, to: Me::Edit, class: nav_item_class(active: current_path == Me::Edit.path) }
            else
              li { link "注册", to: SignUps::New, class: nav_item_class(active: current_path == SignUps::New.path) }
              li { link "登录", to: SignIns::New, class: nav_item_class(active: current_path == SignIns::New.path) }
            end
          end
        end
      end
    end

    div class: "flex justify-end" do
      mount Shared::FlashMessages, context.flash
    end
  end

  private def nav_item_class(*, active : Bool = false)
    base = "inline-flex items-center rounded-md px-3 py-1.5 text-sm font-medium no-underline transition"
    active_classes = "bg-gray-200 text-gray-950"
    inactive_classes = "text-gray-800 hover:bg-gray-100 hover:text-gray-950"

    "#{base} #{active ? active_classes : inactive_classes}"
  end
end
