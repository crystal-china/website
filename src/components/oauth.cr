class Component::OAuth < BaseComponent
  def render
    aside class: "flex h-full flex-col justify-center rounded-3xl border border-gray-200 bg-white p-6 shadow-sm" do
      div class: "space-y-6" do
        div do
          h2 "快捷登录", class: "text-lg font-semibold text-gray-900"
          para "如果你之前绑定过第三方账号，可以直接使用。", class: "mt-2 text-sm leading-6 text-gray-600"
        end

        div class: "space-y-3" do
          link "Google", to: SignUps::Oauth::New.with(provider: "google"), hx_boost: "false", class: "form-secondary w-full"
          link "Github", to: SignUps::Oauth::New.with(provider: "github"), hx_boost: "false", class: "form-secondary w-full"
        end
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
