require "./main_layout"

abstract class DocLayout < MainLayout
  include MarkdownHelpers

  needs formatter : Tartrazine::Formatter
  needs doc : Doc
  needs markdown_path : String
  needs markdown_source : String

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

  private def render_body
    if paginated_doc?
      render_paginated_doc
    else
      render_standalone_doc
    end

    mount Shared::Common, page_title: page_title
    mount Comments::Dialog
  end

  private def paginated_doc?
    DocNavigation.pages_by_path.has_key?(current_path)
  end

  private def render_paginated_doc
    render_navbar_and_flash

    main class: "#{page_frame_classes} flex flex-col items-stretch lg:flex-row lg:items-start" do
      aside class: "w-full border-b border-gray-300 bg-[#F2F4F6] lg:w-80 lg:shrink-0 lg:self-stretch lg:border-r lg:border-b-0" do
        header id: "sidebar", class: "desktop-sidebar #{page_gutter_classes} py-2 lg:w-80" do
          mount Sidebar, current_user: current_user
        end
      end

      render_content_column(
        section_class: "min-w-0 w-full flex-1 pt-6 #{page_gutter_classes} lg:pt-0 lg:pl-20",
        article_class: "w-full max-w-[90ch]",
        show_pager: true
      )
    end

    mount Search::Dialog, scope: search_scope, current_user: current_user if current_user
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

  private def search_scope : String
    "docs"
  end
end
