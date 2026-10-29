require "../spec_helper"

describe "Password reset navigation" do
  around_each do |example|
    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      example.run
    end
  end

  it "keeps failed reset requests on the original form URL" do
    response = ApiClient.new.headers("HX-Request-Type": "full").post(
      "/password_reset_requests",
      request_password_reset: {email: "missing@example.com"}
    )

    response.status_code.should eq(200)
    response.headers["HX-Push-Url"].should eq("false")
    response.headers["Location"]?.should be_nil
    form = XML.parse_html(response.body).xpath_node("//form[@action='/password_reset_requests']").not_nil!

    form.xpath_node(".//input[@name='request_password_reset:email']").not_nil!["value"].should eq("missing@example.com")
  end

  it "keeps failed password changes on the edit URL and still redirects after success" do
    user = UserFactory.create
    token = Authentic.generate_password_reset_token(user)
    entry = ApiClient.new.get("/password_resets/#{user.id}?token=#{URI.encode_www_form(token)}")
    headers = HTTP::Headers.new

    HTTP::Cookies.from_server_headers(entry.headers).add_request_headers(headers)

    client = ApiClient.new.headers(Cookie: headers["Cookie"], "HX-Request-Type": "full")
    response = client.post(
      "/password_resets/#{user.id}",
      user: {password: "new-password", password_confirmation: "different-password"}
    )

    response.status_code.should eq(200)
    response.headers["HX-Push-Url"].should eq("false")
    response.headers["Location"]?.should be_nil
    UserQuery.find(user.id).encrypted_password.should eq(user.encrypted_password)
    XML.parse_html(response.body).xpath_node("//form[@action='/password_resets/#{user.id}']").should_not be_nil

    response = client.post(
      "/password_resets/#{user.id}",
      user: {password: "new-password", password_confirmation: "new-password"}
    )

    response.status_code.should eq(303)
    response.headers["Location"].should eq(Home::Index.path)
    response.headers["HX-Push-Url"]?.should be_nil
    UserQuery.find(user.id).encrypted_password.should_not eq(user.encrypted_password)
  end
end
