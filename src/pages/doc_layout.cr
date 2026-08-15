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

      body hx_boost: true do
        div do
          mount Navbar, current_user: current_user

          div class: "#{page_frame_classes} flex items-start" do
            aside class: "w-80 shrink-0 self-stretch border-r border-gray-300 bg-[#F2F4F6]" do
              header id: "sidebar", class: "sticky top-6 #{page_gutter_classes} py-2" do
                mount Sidebar, current_user: current_user
              end
            end

            div class: "min-w-0 flex-1 #{page_gutter_classes} pl-20" do
              main class: "w-full max-w-[90ch]" do
                div class: "doc-page-header" do
                  h1 class: "doc-page-title" do
                    text page_title
                  end

                  if (msg = sub_title)
                    para class: "doc-page-subtitle" do
                      text msg
                    end
                  end

                  div class: "doc-page-meta" do
                    doc = find_or_create_doc
                    raw print_doc_info(doc)
                    print_votes(doc)
                  end
                end

                content

                footer class: "mt-10" do
                  mount Pager
                end

                div class: "mt-8 flex justify-center text-gray-400" do
                  text "欢迎在评论区留下你的见解、问题或建议"
                end

                div id: "form_with_replies", class: "mt-6" do
                  # 只是一个占位符，会被 htmx 请求覆盖
                  mount ::Docs::ReplyToDocForm, current_user: current_user, doc_path: current_path

                  show_replies_when_revealed
                end

                footer class: "mt-12" do
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
      class: "mx-auto mt-[16vh] h-[40em] max-h-full w-[30em] max-w-full"
    ) do
      label "注意：中文搜索结果通常不准确, 请使用英文关键字！", for: "search-input", class: "titlebar"

      div class: "flex h-[40em] max-h-full w-[30em] max-w-full flex-col" do
        div class: "stork-wrapper-flat" do
          input data_stork: "docs", class: "stork-input", id: "search-input"
          div data_stork: "docs-output", class: "stork-output"
        end
      end
    end
  end
end
