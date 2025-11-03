abstract class DocLayout
  include Lucky::HTMLPage
  include PageHelpers
  include MarkdownHelpers

  # 'needs current_user : User' makes it so that the current_user
  # is always required for pages using MainLayout
  needs current_user : User?
  needs formatter : Tartrazine::Formatter

  def page_title
    PAGINATION_RELATION_MAPPING.dig?(current_path, :title) || "文档"
  end

  def sub_title
    PAGINATION_RELATION_MAPPING.dig?(current_path, :sub_title)
  end

  def render
    html_doctype

    html lang: "en", class: "-no-dark-theme" do
      mount Shared::LayoutHead, page_title: page_title

      body hx_boost: true, style: "padding: 0px;" do
        div do
          mount Navbar, current_user: current_user

          div class: "sidebar-layout fullscreen" do
            header id: "sidebar" do
              mount Sidebar, current_user: current_user
            end

            div do
              main style: "--density: 0.6" do
                h1 do
                  text page_title
                  if (msg = sub_title)
                    tag "sub-title" do
                      text msg
                    end
                  end
                end

                div class: "f-row justify-content:space-between" do
                  doc = find_or_create_doc
                  raw print_doc_info(doc)
                  print_votes(doc)
                end

                content

                footer do
                  mount Pager
                end

                div class: "<h5> f-row justify-content:center", style: "color: #BEBEBE" do
                  text "欢迎在评论区留下你的见解、问题或建议"
                end

                div id: "form_with_replies" do
                  # 只是一个占位符，会被 htmx 请求覆盖
                  mount ::Docs::ReplyToDocForm, current_user: current_user, doc_path: current_path

                  show_replies_when_revealed
                end

                footer class: "f-row flex-wrap:wrap justify-content:center" do
                  mount Footer, current_user: current_user
                end
              end
            end

            mount Shared::Common, page_title: page_title
          end

          doc_search_dialog
        end
      end
    end
  end

  private def doc_search_dialog
    dialog(
      id: "doc_search_dialog",
      class: "margin f-col",
      style: "max-width: 100%; width: 30em;
max-height: 100%; height: 40em;
padding-bottom: 0;") do
      label "注意：中文搜索结果通常不准确, 请使用英文关键字！", for: "search-input", class: "titlebar", style: "margin-inline: calc(-1*var(--gap))"

      div class: "stork-wrapper-flat" do
        input data_stork: "docs", class: "stork-input", id: "search-input"
        div data_stork: "docs-output", class: "stork-output"
      end
    end
  end
end
