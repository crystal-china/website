class OAuth < BaseComponent
  needs providers : Array(String)

  def render : Nil
    aside class: "app-panel flex h-full flex-col justify-center gap-6 p-6" do
      header do
        h2 r(".title").t, class: "m-0 text-lg font-semibold text-gray-900"
        para r(".description").t, class: "mt-2 mb-0 text-sm leading-6 text-gray-600"
      end

      nav class: "space-y-3", "aria-label": r(".providers").t do
        link "Google", to: SignUps::Oauth::New.with(provider: "google"), hx_boost: "false", class: "form-secondary w-full" if providers.includes?("google")
        link "Github", to: SignUps::Oauth::New.with(provider: "github"), hx_boost: "false", class: "form-secondary w-full" if providers.includes?("github")
      end
    end

    # para do
    #   strong do
    #     link "Twitter", to: SignUps::Oauth::New.with(provider: "twitter"), hx_boost: "false"
    #   end
    # end

    # para do
    #   strong do
    #     link "Facebook", to: SignUps::Oauth::New.with(provider: "facebook"), hx_boost: "false"
    #   end
    # end
  end
end
