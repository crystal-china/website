module AuthPageHelpers
  def auth_card(title : String, description : String, &) : Nil
    article class: "app-panel w-full overflow-hidden" do
      header class: "panel-header" do
        h1 title, class: "panel-title"
        para description, class: "panel-description"
      end

      yield
    end
  end

  def auth_page_with_oauth(&) : Nil
    providers = [] of String
    providers << "google" if ENV["GOOGLE_OAUTH_CLIENT_ID"]?.presence && ENV["GOOGLE_OAUTH_SECRET"]?.presence
    providers << "github" if ENV["GITHUB_OAUTH_CLIENT_ID"]?.presence && ENV["GITHUB_OAUTH_SECRET"]?.presence

    if providers.empty?
      auth_page_single_column { yield }
    else
      section class: "mx-auto grid w-full max-w-4xl gap-8 px-8 py-12 lg:grid-cols-[minmax(0,1fr)_18rem]" do
        yield
        mount Component::OAuth, providers: providers
      end
    end
  end

  def auth_page_single_column(&) : Nil
    section class: "mx-auto w-full max-w-3xl px-8 py-12" do
      yield
    end
  end

  def auth_form_fields(&) : Nil
    div class: "mx-auto w-full max-w-sm space-y-6" do
      yield
    end
  end

  def auth_form_actions(justify : String = "justify-between", &) : Nil
    div class: "flex flex-wrap items-center #{justify} gap-3 border-t border-gray-200 pt-6" do
      yield
    end
  end
end
