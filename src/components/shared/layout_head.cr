class Shared::LayoutHead < BaseComponent
  needs page_title : String

  def render
    head do
      utf8_charset
      title "Crystal China - #{@page_title}"

      css_link asset("css/app.css")
      script type: "application/json", id: "app-config" do
        raw frontend_config.to_json
      end
      js_link asset("js/app.js"), defer: "true"

      csrf_meta_tags
      responsive_meta_tag
      # css_link "https://fonts.googleapis.com/icon?family=Material+Icons"

      # css_link "https://fonts.bunny.net/css?family=source-sans-3:400,700|m-plus-code-latin:400,700"

      bun_reload_connect_tag
    end
  end

  private def frontend_config
    {
      assetHost: Lucky::Server.settings.asset_host,
      assetBasePath: "/assets",
      firebaseConfig: {
        apiKey: ENV["VITE_FIREBASE_API_KEY"]?,
        authDomain: ENV["VITE_FIREBASE_AUTH_DOMAIN"]?,
        projectId: ENV["VITE_FIREBASE_PROJECT_ID"]?,
        storageBucket: ENV["VITE_FIREBASE_STORAGE_BUCKET"]?,
        messagingSenderId: ENV["VITE_FIREBASE_MESSAGING_SENDER_ID"]?,
        appId: ENV["VITE_FIREBASE_APP_ID"]?,
        measurementId: ENV["VITE_FIREBASE_MEASUREMENT_ID"]?,
      },
    }
  end
end
