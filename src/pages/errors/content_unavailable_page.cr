class Errors::ContentUnavailablePage < MainLayout
  needs content_name : String

  def page_title : String
    r(".page_title").t(name: content_name)
  end

  def content : Nil
    section class: "#{page_container_classes} py-10" do
      div class: "app-panel mx-auto max-w-2xl px-6 py-10 sm:px-8" do
        para "404", class: "m-0 text-sm font-semibold text-gray-400"
        h1 page_title, class: "mt-3 text-2xl font-semibold text-gray-900"
        para r(".description").t(name: content_name), class: "mt-4 text-gray-600"

        nav class: "mt-6 flex flex-wrap gap-3", "aria-label": r(".other_pages").t do
          link(
            r(".view_community").t,
            to: Forum::Index,
            class: "form-secondary"
          )
          link(
            r(".view_docs").t,
            to: Docs::Markdowns.with(requested_path: "index"),
            class: "form-secondary"
          )
        end
      end
    end
  end
end
