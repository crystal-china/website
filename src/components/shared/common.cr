class Shared::Common < BaseComponent
  needs page_title : String

  def render : Nil
    # 放在 body 中，确保 hx-boost 导航后同步切换前端提示语言。
    mount Shared::Translations, current_user: current_user

    div(
      id: "page-analytics",
      hidden: true,
      data_page_path: current_path,
      data_page_title: page_title,
    )
  end
end
