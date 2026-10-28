require "../spec_helper"

private def follow_node_save_redirect(response : HTTP::Client::Response) : HTTP::Client::Response
  headers = HTTP::Headers.new

  HTTP::Cookies.from_server_headers(response.headers).add_request_headers(headers)

  ApiClient.new.headers(Cookie: headers["Cookie"]).get(response.headers["Location"])
end

describe "Admin node saves" do
  around_each do |example|
    previous_emails = ENV["ADMIN_EMAILS"]?
    ENV["ADMIN_EMAILS"] = "node-actions-admin@example.com"

    Lucky::ProtectFromForgery.temp_config(allow_forgery_protection: false) do
      example.run
    end
  ensure
    if previous_emails
      ENV["ADMIN_EMAILS"] = previous_emails
    else
      ENV.delete("ADMIN_EMAILS")
    end
  end

  it "redirects to the freshly sorted node list after creating or updating a node" do
    admin = UserFactory.create &.email("node-actions-admin@example.com")
    client = ApiClient.new.headers("HX-Request-Type": "full")
    original = SaveNode.create!(name: "原有节点", slug: "original-node", summary: "原有简介", color: "#16a34a", position: 1)
    response = client.post(
      "/admin/nodes?backdoor_user_id=#{admin.id}&locale=zh-CN",
      node: {name: "新增节点", slug: "created-node", summary: "新增简介", color: "#0284c7", position: 0}
    )

    response.status_code.should eq(303)
    response.headers["Location"].should eq("/admin/nodes")
    response.headers["HX-Push-Url"]?.should be_nil

    created = NodeQuery.new.slug("created-node").first
    response = follow_node_save_redirect(response)
    document = XML.parse_html(response.body)
    rows = document.xpath_nodes("//main//tbody/tr").to_a

    response.status_code.should eq(200)
    response.headers["Location"]?.should be_nil
    response.headers["HX-Push-Url"]?.should be_nil
    rows.map { |row| row.xpath_node("./td[2]").not_nil!.content }.should eq([original.slug, created.slug])
    document.xpath_node("//main//form").should be_nil
    document.xpath_node("//div[contains(@class, 'flash-message--success')]").should_not be_nil

    response = client.put(
      "/admin/nodes/#{created.id}?backdoor_user_id=#{admin.id}&locale=zh-CN",
      node: {name: "更新后的节点", slug: "updated-node", summary: "更新简介", color: "#dc2626", position: 2}
    )

    response.status_code.should eq(303)
    response.headers["Location"].should eq("/admin/nodes")
    response.headers["HX-Push-Url"]?.should be_nil

    response = follow_node_save_redirect(response)
    document = XML.parse_html(response.body)
    rows = document.xpath_nodes("//main//tbody/tr").to_a

    response.status_code.should eq(200)
    response.headers["Location"]?.should be_nil
    response.headers["HX-Push-Url"]?.should be_nil
    rows.map { |row| row.xpath_node("./td[2]").not_nil!.content }.should eq(["updated-node", original.slug])
    rows.first.content.should contain("更新后的节点")
    rows.first.content.should contain("更新简介")
    rows.first.xpath_node(".//a[@href='/forum?node=updated-node']").should_not be_nil
    document.xpath_node("//link[@rel='canonical']").not_nil!["href"].should eq("#{Lucky::RouteHelper.settings.base_uri}/admin/nodes")
    document.xpath_node("//div[@id='page-analytics']").not_nil!["data-page-path"]?.should be_nil
    NodeQuery.find(created.id).name.should eq("更新后的节点")

    refreshed = client.get("/admin/nodes?backdoor_user_id=#{admin.id}&locale=zh-CN")

    refreshed.status_code.should eq(200)
    refreshed.body.should contain("更新后的节点")
    refreshed.body.should_not contain("flash-message--success")
  end

  it "keeps invalid submissions on their forms without changing data or the browser URL" do
    admin = UserFactory.create &.email("node-actions-admin@example.com")
    client = ApiClient.new.headers("HX-Request-Type": "full")
    node = SaveNode.create!(name: "原有节点", slug: "unchanged-node", summary: "原有简介", color: "#16a34a", position: 1)
    attributes = {name: "未保存的节点", slug: "invalid-node", summary: "未保存简介", color: "invalid", position: 0}

    {
      {"post", "/admin/nodes"},
      {"put", "/admin/nodes/#{node.id}"},
    }.each do |method, path|
      request_path = "#{path}?backdoor_user_id=#{admin.id}&locale=zh-CN"
      response = if method == "post"
                   client.post(request_path, node: attributes)
                 else
                   client.put(request_path, node: attributes)
                 end

      document = XML.parse_html(response.body)
      form = document.xpath_node("//main//form").not_nil!

      response.status_code.should eq(200)
      response.headers["Location"]?.should be_nil
      response.headers["HX-Push-Url"].should eq("false")
      form["hx-push-url"]?.should be_nil
      form["action"].should eq(path)
      form.xpath_node(".//input[@name='node:name']").not_nil!["value"].should eq("未保存的节点")
      document.xpath_node("//div[contains(@class, 'flash-message--failure')]").should_not be_nil
      NodeQuery.new.select_count.should eq(1)
      NodeQuery.find(node.id).name.should eq("原有节点")
    end
  end

  it "rejects node changes from non-administrators" do
    user = UserFactory.create
    node = SaveNode.create!(name: "原有节点", slug: "protected-node", summary: "原有简介", color: "#16a34a", position: 1)
    client = ApiClient.new.headers("HX-Request-Type": "full")
    attributes = {name: "无权修改", slug: "forbidden-node", summary: "简介", color: "#0284c7", position: 0}

    client.post("/admin/nodes?backdoor_user_id=#{user.id}", node: attributes).status_code.should eq(404)
    client.put("/admin/nodes/#{node.id}?backdoor_user_id=#{user.id}", node: attributes).status_code.should eq(404)
    NodeQuery.new.select_count.should eq(1)
    NodeQuery.find(node.id).name.should eq("原有节点")
  end
end
