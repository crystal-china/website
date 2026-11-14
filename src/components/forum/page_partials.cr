# 社区区域替换后，同步区域外的页面元数据、访问统计和已读通知计数。
class Forum::PagePartials < BaseComponent
  needs seo : SEO

  def render : Nil
    title "Crystal China - #{seo.page_title}"

    tag(
      "hx-partial",
      hx_target: "head link[rel='canonical']",
      hx_swap: "outerHTML"
    ) do
      tag(
        "link",
        rel: "canonical",
        href: seo.canonical_url
      )
    end

    tag(
      "hx-partial",
      hx_target: "head meta[property='og:title']",
      hx_swap: "outerHTML"
    ) do
      meta property: "og:title", content: seo.page_title
    end

    tag(
      "hx-partial",
      hx_target: "head meta[property='og:url']",
      hx_swap: "outerHTML"
    ) do
      meta property: "og:url", content: seo.canonical_url
    end

    tag(
      "hx-partial",
      hx_target: "head meta[name='twitter:title']",
      hx_swap: "outerHTML"
    ) do
      meta name: "twitter:title", content: seo.page_title
    end

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
