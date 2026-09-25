abstract class DocLayout
  include Lucky::HTMLPage
  include PageHelpers
  include MarkdownHelpers

  # 'needs current_user : User' makes it so that the current_user
  # is always required for pages using MainLayout
  needs current_user : User?
  needs formatter : Tartrazine::Formatter
  needs doc : Doc
  needs markdown_path : String
  needs markdown_source : String

  abstract def content

  def page_title
    DocNavigation.pages_by_path[current_path]?.try(&.title) || markdown_page_title
  end

  def sub_title
    DocNavigation.pages_by_path[current_path]?.try(&.sub_title) || markdown_page_sub_title
  end

  def page_description
    if (description = sub_title) && !description.empty?
      return "#{page_title}：#{description}。"
    end

    "#{page_title} - Crystal 中文文档。"
  end

  def render
    html_doctype

    html lang: "zh-CN" do
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

          if paginated_doc?
            render_paginated_doc
          else
            render_standalone_doc
          end

          mount Shared::Common, page_title: page_title
          mount Comments::Dialog
        end
      end
    end
  end

  private def paginated_doc?
    DocNavigation.pages_by_path.has_key?(current_path)
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

        div class: "mt-6 flex justify-end" do
          a(
            "在 GitHub 编辑此页",
            href: "https://github.com/crystal-china/website/edit/master/#{URI.encode_path(markdown_path)}",
            target: "_blank",
            rel: "noopener",
            class: "text-sm text-gray-500 underline decoration-dotted underline-offset-4 transition hover:text-sky-700 hover:decoration-solid"
          )
        end

        para class: "mt-8 mb-0 text-center text-gray-400" do
          text "欢迎在评论区留下你的见解、问题或建议"
        end

        section id: "form_with_comments", class: "mt-6" do
          # 只是一个占位符，会被 htmx 请求覆盖
          comment_thread = CommentThreadQuery.new.doc_id(doc.id).first
          mount(
            ::Comments::Form,
            current_user: current_user,
            comment_thread_id: comment_thread.id
          )

          show_comments_when_revealed(comment_thread.id)
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
        raw print_doc_info(doc)
        print_votes(doc)
      end
    end
  end

  private def print_doc_info(doc)
    doc_info = "创建于：#{doc.created_at.to_s("%Y年%m月%d日")}"

    if (modified_at = doc.content_updated_at)
      doc_info = "#{doc_info}       最后编辑于: #{modified_at.to_local.to_s("%Y年%m月%d日")}"
    end

    doc_info = "#{doc_info}  | #{doc.view_count}次阅读" if doc.view_count > 0

    %(<p class="doc-page-meta-text">#{doc_info}</p>)
  end

  private def print_votes(doc)
    me = current_user

    voted_types = if me.nil?
                    [] of String
                  else
                    VoteQuery.new.user_id(me.id).doc_id(doc.id).map &.vote_type
                  end

    div class: "doc-page-votes" do
      mount(
        Shared::VoteButton,
        vote_counts: Hash(String, Int32).from_json(doc.vote_counts.to_json),
        doc_id: doc.id,
        current_user: me,
        voted_types: voted_types
      )
    end
  end

  private def doc_search_dialog
    dialog(
      id: "doc_search_dialog",
      class: "mx-auto mt-[8vh] h-[40em] max-h-[calc(100vh_-_2rem)] w-[calc(100%_-_2rem)] sm:mt-[16vh] sm:w-[30em]"
    ) do
      label "注意：中文搜索结果通常不准确, 请使用英文关键字！", for: "search-input", class: "titlebar"

      div class: "stork-wrapper-flat mt-3" do
        input data_stork: "docs", data_stork_index_url: stork_index_url, class: "stork-input", id: "search-input"
        div data_stork: "docs-output", class: "stork-output"
      end
    end
  end

  private def stork_index_url
    path = "public/markdowns/search-index.st"
    version_path = "#{path}.version"
    version = File.read(version_path).strip if File.file?(version_path)

    version ? "/markdowns/search-index.st?v=#{version}" : "/markdowns/search-index.st"
  end
end
