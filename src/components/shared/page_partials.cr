# 局部导航共用完整 head，由 hx-head 合并；统计和铃铛仍按各自目标更新。
class Shared::PagePartials < BaseComponent
  needs seo : SEO

  def render : Nil
    mount Shared::LayoutHead, seo: seo

    tag(
      "hx-partial",
      hx_target: "#page-analytics",
      hx_swap: "outerHTML"
    ) do
      div(
        id: "page-analytics",
        hidden: true,
        data_page_title: seo.page_title
      )
    end

    if current_user
      tag(
        "hx-partial",
        hx_target: "#notification-status",
        hx_swap: "outerHTML"
      ) do
        mount Navbar::NotificationButton
      end
    end
  end
end
