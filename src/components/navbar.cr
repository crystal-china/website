class Navbar < BaseComponent
  def render
    header class: "sticky top-0 z-50" do
      div class: "flex translate-y-px flex-col items-center gap-3 border-b border-black bg-[#F2F4F6] pt-3 pb-3 md:flex-row md:justify-between md:pt-4 #{page_frame_classes} #{page_gutter_classes}" do
        a href: "/", class: "inline-flex shrink-0 items-center" do
          img src: asset("svgs/crystal.svg"), alt: "crystal-china", class: "w-[140px] sm:w-[180px]"
          span "China", class: "ml-3 text-base font-semibold tracking-wide text-black uppercase sm:ml-6 sm:text-lg"
        end

        nav class: "w-full md:ml-auto md:w-auto" do
          ul class: "m-0 flex list-none flex-wrap items-center justify-center gap-x-2 gap-y-2 p-0 sm:gap-x-4 md:justify-end lg:gap-x-6" do
            li do
              if current_path.starts_with?("/docs")
                button(
                  "搜索文档",
                  class: nav_item_class(active: true),
                  onclick: "document.getElementById('doc_search_dialog').showModal();",
                  flow_id: "doc_index"
                )
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
  end

  private def nav_item_class(*, active : Bool = false)
    base = "inline-flex items-center rounded-md px-3 py-1.5 text-sm font-medium no-underline"
    active_classes = "bg-gray-300 text-gray-950"
    inactive_classes = "text-gray-800 hover:bg-gray-200 hover:text-gray-950"

    "#{base} #{active ? active_classes : inactive_classes}"
  end
end
