require "../spec_helper"

describe "OAuth sign-in" do
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
