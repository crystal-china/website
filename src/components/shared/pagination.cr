class Shared::Pagination < BaseComponent
  needs pages : Lucky::Paginator
  needs classes : String = "mt-6 flex items-center justify-center gap-4 text-sm"

  def render : Nil
    return if pages.total <= 1

    nav(class: classes) do
      render_page_link(r("common.previous_page").t, pages.path_to_previous)
      span r("common.page_number").t(page: pages.page.to_s, total: pages.total.to_s), class: "text-gray-600"
      render_page_link(r("common.next_page").t, pages.path_to_next)
    end
  end

  private def render_page_link(label : String, path : String?) : Nil
    if path
      a label, href: path, class: "form-secondary"
    else
      span label, class: "form-secondary cursor-not-allowed opacity-50"
    end
  end
end
