abstract class MainLayout
  include Lucky::HTMLPage
  include PageHelpers

  needs current_user : User?

  abstract def content : Nil

  def page_title : String
    r("main_layout.page_title").t
  end

  def page_description : String
    r("main_layout.description").t
  end

  def render : Nil
    html_doctype

    html lang: Rosetta.locale do
      mount(
        Shared::LayoutHead,
        seo: SEO.new(
          page_title: page_title,
          page_description: page_description,
          canonical_url: canonical_url
        )
      )

      body "hx-boost:inherited": "true" do
        # hx-boost 替换 body 时，会对每个顶级子元素分别触发 htmx.onLoad。
        # 保持 body 下只有这个根元素，确保整页替换时只触发一次；不要删除。
        div id: "htmx-onload-root" do
          mount Shared::HtmxErrorAlert
          render_body
        end
      end
    end
  end

  private def render_body : Nil
    scope = search_scope

    render_navbar_and_flash

    main do
      content
    end

    mount Footer, current_user: current_user

    if current_user && scope
      mount(
        Search::Dialog,
        scope: scope,
        current_user: current_user
      )
    end

    mount Shared::Common, page_title: page_title
  end

  private def render_navbar_and_flash : Nil
    mount(
      Navbar,
      current_user: current_user,
      search_scope: search_scope
    )
    mount Shared::PageFlash, flash: context.flash
    mount ::Notifications::Dialog, current_user: current_user if current_user
  end

  private def search_scope : String?
    nil
  end
end
