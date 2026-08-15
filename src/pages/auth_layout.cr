abstract class AuthLayout
  include Lucky::HTMLPage

  needs current_user : User?

  abstract def content
  abstract def page_title

  # The default page title. It is passed to `Shared::LayoutHead`.
  #
  # Add a `page_title` method to pages to override it. You can also remove
  # This method so every page is required to have its own page title.
  def page_title
    "Welcome"
  end

  def render
    html_doctype

    html lang: "en" do
      mount Shared::LayoutHead, page_title: page_title

      body do
        div do
          mount Navbar, current_user: current_user

          main do
            content
          end

          footer class: "f-row flex-wrap:wrap justify-content:center" do
            mount Footer, current_user: current_user
          end
          mount Shared::Common, page_title: page_title
        end
      end
    end
  end

  def auth_card(title : String, description : String, &)
    article class: "w-full overflow-hidden rounded-2xl border border-gray-200 bg-white shadow-sm" do
      div class: "border-b border-gray-200 bg-gradient-to-r from-sky-50 via-white to-cyan-50 px-8 py-7" do
        h1 title, class: "text-3xl font-semibold tracking-tight text-gray-900"
        para description, class: "mt-2 text-sm leading-6 text-gray-600"
      end

      yield
    end
  end
end
