require "../spec_helper"

describe "OAuth sign-in" do
  it "renders the provider component with localized labels on authentication pages" do
    client_id = ENV["GITHUB_OAUTH_CLIENT_ID"]?
    secret = ENV["GITHUB_OAUTH_SECRET"]?
    ENV["GITHUB_OAUTH_CLIENT_ID"] = "test-client"
    ENV["GITHUB_OAUTH_SECRET"] = "test-secret"

    {"zh-CN" => "快捷登录", "en" => "Sign in with a provider"}.each do |locale, title|
      {SignIns::New.path, SignUps::New.path}.each do |path|
        response = ApiClient.new.get("#{path}?locale=#{locale}")
        document = XML.parse_html(response.body)

        response.status_code.should eq(200)
        document.xpath_node("//aside//h2").not_nil!.content.should eq(title)
        document.xpath_node("//aside//a[@href='/multi_auth/github']").should_not be_nil
      end
    end
  ensure
    if client_id
      ENV["GITHUB_OAUTH_CLIENT_ID"] = client_id
    else
      ENV.delete("GITHUB_OAUTH_CLIENT_ID")
    end
    if secret
      ENV["GITHUB_OAUTH_SECRET"] = secret
    else
      ENV.delete("GITHUB_OAUTH_SECRET")
    end
  end

  {"github" => "github.com", "google" => "accounts.google.com"}.each do |provider, host|
    it "redirects #{provider} sign-in to the registered provider with state" do
      response = ApiClient.new.get("/multi_auth/#{provider}")
      response.status_code.should eq(303)

      authorize_uri = URI.parse(response.headers["Location"])
      authorize_uri.scheme.should eq("https")
      authorize_uri.host.should eq(host)
      authorize_uri.query_params["redirect_uri"].should eq("#{Lucky::RouteHelper.settings.base_uri}/multi_auth/#{provider}/callback")
      authorize_uri.query_params["state"].should match(/\A[0-9a-f]{64}\z/)
    end
  end
end
