class Search::Result < BaseComponent
  needs title : String
  needs url : String
  needs snippet : String

  def render : Nil
    li do
      a href: url, class: "block px-4 py-3 no-underline transition-colors hover:bg-sky-50 focus-visible:bg-sky-50" do
        strong title, class: "text-sm text-sky-800"

        para class: "doc-search-snippet mt-1 mb-0 line-clamp-3 text-xs leading-relaxed text-gray-600" do
          raw snippet
        end
      end
    end
  end
end
