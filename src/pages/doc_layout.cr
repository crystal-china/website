abstract class DocLayout
  include Lucky::HTMLPage
  include PageHelpers
  include MarkdownHelpers

  # 'needs current_user : User' makes it so that the current_user
  # is always required for pages using MainLayout
  needs current_user : User?
  needs formatter : Tartrazine::Formatter

  def page_title
    PAGINATION_RELATION_MAPPING.dig?(current_path, :title) || markdown_page_title
  end

  def sub_title
    PAGINATION_RELATION_MAPPING.dig?(current_path, :sub_title) || markdown_page_sub_title
  end

  def render
    html_doctype

    html lang: "zh-CN" do
      mount Shared::LayoutHead, page_title: page_title

      body hx_boost: true do
        if paginated_doc?
          render_paginated_doc
        else
          render_standalone_doc
        end

        mount Shared::Common, page_title: page_title
        mount Docs::ReplyDialog
      end
    end
  end

  private def paginated_doc?
    PAGINATION_RELATION_MAPPING.has_key?(current_path)
  end

  private def render_paginated_doc
    mount Navbar, current_user: current_user
    mount Shared::PageFlash, flash: context.flash

    main class: "#{page_frame_classes} flex flex-col items-stretch lg:flex-row lg:items-start" do
      aside class: "w-full border-b border-gray-300 bg-[#F2F4F6] lg:w-80 lg:shrink-0 lg:self-stretch lg:border-r lg:border-b-0" do
        header id: "sidebar", class: "#{page_gutter_classes} py-2 lg:sticky lg:top-6" do
          mount Sidebar, current_user: current_user
        end
      end

      render_content_column(
        section_class: "min-w-0 w-full flex-1 pt-6 #{page_gutter_classes} lg:pt-0 lg:pl-20",
        article_class: "w-full max-w-[90ch]",
        show_pager: true
      )
    end

    doc_search_dialog
  end

  private def render_standalone_doc
    main class: page_container_classes do
      render_content_column(
        section_class: "w-full",
        article_class: "mx-auto w-full max-w-[90ch]",
        show_pager: false
      )
    end
  end

  private def render_content_column(*, section_class : String, article_class : String, show_pager : Bool)
    section class: section_class do
      article class: article_class do
        render_page_header

        content

        if show_pager
          nav class: "mt-10", "aria-label": "文档分页" do
            mount Pager
          end
        end

        para class: "mt-8 text-center text-gray-400" do
          text "欢迎在评论区留下你的见解、问题或建议"
        end

        section id: "form_with_replies", class: "mt-6" do
          # 只是一个占位符，会被 htmx 请求覆盖
          mount ::Docs::ReplyToDocForm, current_user: current_user, doc_path: current_path

          show_replies_when_revealed
        end
      end

      mount Footer, current_user: current_user
    end
  end

  private def render_page_header
    header class: "doc-page-header" do
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
  end

  private def doc_search_dialog
    dialog(
      id: "doc_search_dialog",
      class: "mx-auto mt-[8vh] h-[40em] max-h-[calc(100vh_-_2rem)] w-[calc(100%_-_2rem)] sm:mt-[16vh] sm:w-[30em]"
    ) do
      label "注意：中文搜索结果通常不准确, 请使用英文关键字！", for: "search-input", class: "titlebar"

      div class: "stork-wrapper-flat mt-3" do
        input data_stork: "docs", class: "stork-input", id: "search-input"
        div data_stork: "docs-output", class: "stork-output"
      end
    end
  end
end
