class Navbar < BaseComponent
  def render
    header class: "mx-auto mb-0.5 flex w-full max-w-7xl items-center justify-between gap-6 px-8" do
      a href: "/", class: "inline-flex shrink-0 items-center" do
        img src: asset("svgs/crystal.svg"), alt: "crystal-china", class: "w-[150px]"
        span "China", class: "ml-4 text-black uppercase"
      end

      nav class: "flex flex-1 justify-end" do
        ul class: "flex flex-wrap items-center justify-end gap-x-6 gap-y-2" do
          li do
            if current_path.starts_with?("/docs")
              tag "search" do
                strong do
                  button "搜索文档", onclick: "document.getElementById('doc_search_dialog').showModal();", flow_id: "doc_index"
                end
              end
            else
              a "学习文档", href: "/docs/index", flow_id: "doc_index"
            end
          end

          li do
            a "本站源码", href: "https://github.com/crystal-china/website"
          end

          me = current_user
          if me
            li do
              link(
                "登出",
                to: SignIns::Delete,
                flow_id: "sign-out-button",
                hx_target: "body",
                hx_push_url: "true",
                hx_delete: SignIns::Delete.path,
                hx_include: "[name='_csrf']",
              )
            end

            li { link me.email, to: Me::Edit }
          else
            li { link "注册", to: SignUps::New }
            li { link "登录", to: SignIns::New }
          end
        end
      end
    end

    div class: "flex justify-end" do
      mount Shared::FlashMessages, context.flash
    end
  end
end
