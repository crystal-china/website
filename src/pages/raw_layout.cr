abstract class RawLayout
  include Lucky::HTMLPage
  include PageHelpers
  include MarkdownHelpers

  needs current_user : User?
  needs formatter : Tartrazine::Formatter

  abstract def page_title

  # The default page title. It is passed to `Shared::LayoutHead`.
  #
  # Add a `page_title` method to pages to override it. You can also remove
  # This method so every page is required to have its own page title.
  def page_title
    "皮皮和钱钱的主页"
  end

  def sub_title
    "我们有宝宝啦！"
  end

  def render
    html_doctype

    html lang: "en" do
      mount Shared::LayoutHead, page_title: page_title

      body hx_boost: true do
        div do
          main do
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
    end
  end
end
