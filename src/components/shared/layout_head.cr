class Shared::LayoutHead < BaseComponent
  needs seo : SEO

  def render
    social_preview_url = "#{Lucky::RouteHelper.settings.base_uri}/social-preview.png"

    head do
      utf8_charset
      title "Crystal China - #{seo.page_title}"
      meta name: "description", content: seo.page_description
      tag "link", rel: "canonical", href: seo.canonical_url
      tag "link", rel: "alternate", type: "application/rss+xml", title: "Crystal China 论坛", href: Forum::Feed.url

      meta property: "og:title", content: seo.page_title
      meta property: "og:description", content: seo.page_description
      meta property: "og:url", content: seo.canonical_url
      meta property: "og:type", content: "website"
      meta property: "og:locale", content: "zh_CN"
      meta property: "og:image", content: social_preview_url
      meta property: "og:image:width", content: "1200"
      meta property: "og:image:height", content: "630"
      meta property: "og:image:alt", content: "Crystal China 中文社区"

      meta name: "twitter:card", content: "summary_large_image"
      meta name: "twitter:title", content: seo.page_title
      meta name: "twitter:description", content: seo.page_description
      meta name: "twitter:image", content: social_preview_url

      css_link asset("css/app.css")
      script type: "application/json", id: "app-config" do
        raw frontend_config.to_json
      end
      js_link asset("js/app.js"), defer: "true"

      csrf_meta_tags
      responsive_meta_tag
      # css_link "https://fonts.googleapis.com/icon?family=Material+Icons"

      # css_link "https://fonts.bunny.net/css?family=source-sans-3:400,700|m-plus-code-latin:400,700"

      live_reload_connect_tag if LuckyEnv.development?
      bun_reload_connect_tag
    end
  end

  private def frontend_config
    {
      assetHost:      Lucky::Server.settings.asset_host,
      assetBasePath:  "/assets",
      firebaseConfig: {
        apiKey:            ENV["VITE_FIREBASE_API_KEY"]?,
        authDomain:        ENV["VITE_FIREBASE_AUTH_DOMAIN"]?,
        projectId:         ENV["VITE_FIREBASE_PROJECT_ID"]?,
        storageBucket:     ENV["VITE_FIREBASE_STORAGE_BUCKET"]?,
        messagingSenderId: ENV["VITE_FIREBASE_MESSAGING_SENDER_ID"]?,
        appId:             ENV["VITE_FIREBASE_APP_ID"]?,
        measurementId:     ENV["VITE_FIREBASE_MEASUREMENT_ID"]?,
      },
    }
  end
end
