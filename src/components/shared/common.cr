class Shared::Common < BaseComponent
  needs page_title : String

  def render
    div(
      id: "page-analytics",
      hidden: true,
      data_page_path: current_path,
      data_page_title: page_title,
    )
  end
end
