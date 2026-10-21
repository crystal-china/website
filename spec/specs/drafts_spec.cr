require "../spec_helper"

private def drafts_client(user : User) : ApiClient
  response = ApiClient.new.post("/sign_in", user: {login: user.login_name, password: "password"})
  headers = HTTP::Headers.new
  HTTP::Cookies.from_server_headers(response.headers).add_request_headers(headers)

  ApiClient.new.headers(Cookie: headers["Cookie"])
end

describe "Local editor drafts" do
  around_each do |example|
    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      example.run
    end
  end

  it "marks only topic fields with stable user-specific draft keys" do
    user = UserFactory.create
    node = SaveNode.create!(name: "草稿节点", slug: "drafts", summary: "草稿测试", color: "#0284c7", position: 0)
    topic = CreateTopic.create!(user_id: user.id, node_id: node.id, title: "草稿主题", content: "已保存正文")
    client = drafts_client(user)

    {
      "/forum/new"              => "#{user.id}:topic:new",
      "/forum/#{topic.id}/edit" => "#{user.id}:topic:#{topic.id}:edit",
    }.each do |path, key|
      response = client.get(path)
      document = XML.parse_html(response.body)
      containers = document.xpath_nodes("//*[@data-draft-key]")

      response.status_code.should eq(200)
      containers.size.should eq(1)
      containers.first["data-draft-key"].should eq(key)
      fields = containers.first.xpath_nodes(".//*[@data-draft-field]")
      fields.map(&.["name"]).sort!.should eq(["content", "topic:node_id", "topic:title"])
      fields.each(&.["id"].should_not(be_empty))
      containers.first["hx-push-url"].should eq("false")
    end

    XML.parse_html(ApiClient.new.get("/forum/#{topic.id}").body).xpath_nodes("//*[@data-draft-key]").should be_empty
    XML.parse_html(client.get("/users/#{user.id}/edit").body).xpath_nodes("//*[@data-draft-key]").should be_empty
  end

  it "confirms successful HTMX topic saves before navigating, but keeps ordinary redirects" do
    user = UserFactory.create
    node = SaveNode.create!(name: "提交节点", slug: "draft-save", summary: "提交测试", color: "#0284c7", position: 0)
    client = drafts_client(user)
    response = client.post("/forum", topic: {title: "普通提交", node_id: node.id}, content: "普通正文")

    response.status_code.should eq(303)
    response.headers["X-Draft-Saved"]?.should be_nil

    client.headers("HX-Request-Type": "full")
    response = client.post("/forum", topic: {title: "草稿提交", node_id: node.id}, content: "草稿正文")
    topic = TopicQuery.new.title("草稿提交").first

    response.status_code.should eq(200)
    response.headers["X-Draft-Saved"].should eq("true")
    response.headers["HX-Location"].should eq("/forum/#{topic.id}")

    response = client.put("/forum/#{topic.id}", topic: {title: "修改标题", node_id: node.id}, content: "修改正文")
    response.headers["X-Draft-Saved"].should eq("true")
    response.headers["HX-Location"].should eq("/forum/#{topic.id}")

    cookies = HTTP::Cookies.from_server_headers(response.headers)
    session = Lucky::Session.from_cookie_jar(Lucky::CookieJar.from_request_cookies(cookies))
    session.get?(Lucky::FlashStore::SESSION_KEY).not_nil!.should contain("success")

    response = client.post("/forum", topic: {title: "", node_id: node.id}, content: "")
    response.status_code.should eq(200)
    response.headers["X-Draft-Saved"]?.should be_nil
    response.headers["HX-Location"]?.should be_nil
    response = client.put("/forum/#{topic.id}", content: "")
    response.headers["X-Draft-Saved"]?.should be_nil
  end
end
