abstract class MainLayout
  include Lucky::HTMLPage
  include PageHelpers

  needs current_user : User?

  abstract def content

  def page_title
    "首页"
  end

  def render
    html_doctype

    html lang: "zh-CN" do
      mount Shared::LayoutHead, page_title: page_title

      body "hx-boost:inherited": "true" do
        # hx-boost 替换 body 时，会对每个顶级子元素分别触发 htmx.onLoad。
        # 保持 body 下只有这个根元素，确保整页替换时只触发一次；不要删除。
        div id: "htmx-onload-root" do
          mount Navbar, current_user: current_user
          mount Shared::PageFlash, flash: context.flash

          main do
            content
          end

          mount Footer, current_user: current_user

          mount Shared::Common, page_title: page_title
        end
      end
    end
  end
end
